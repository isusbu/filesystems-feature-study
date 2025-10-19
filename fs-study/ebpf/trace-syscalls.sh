#!/usr/bin/env bash
# trace-syscalls.sh
# Trace syscall counts with bpftrace and write results to a file.
# Usage:
#   ./trace-syscalls.sh            # trace comm="nginx" (default), interactive, stop with Ctrl-C
#   ./trace-syscalls.sh -c redis   # trace processes whose comm == "redis"
#   ./trace-syscalls.sh -a         # trace all processes (no comm filter)
#   ./trace-syscalls.sh -c nginx -o /tmp/out.txt -t 30   # run 30s then stop and save results
#
# Notes:
#  - Requires bpftrace and root privileges (script will use sudo).
#  - bpftrace prints aggregated counters on Ctrl-C (SIGINT). If you use -t (duration),
#    the script will try to send SIGINT to bpftrace so you get the summary in the file.

set -euo pipefail

COMM="nginx"
OUTFILE="tracing.out"
DURATION=0     # seconds, 0 means interactive until Ctrl-C
TRACE_ALL=0

print_help() {
  cat <<EOF
Usage: $0 [options]
Options:
  -c <comm>     Trace processes whose "comm" equals <comm>  (default: nginx)
  -a            Trace all processes (no comm filter)
  -o <file>     Output file (default: tracing.out)
  -t <seconds>  Run for <seconds> then stop and save (default: interactive)
  -h            Show this help
EOF
}

while getopts "c:ao:t:h" opt; do
  case "$opt" in
    c) COMM="$OPTARG" ;;
    a) TRACE_ALL=1 ;;
    o) OUTFILE="$OPTARG" ;;
    t) DURATION="$OPTARG" ;;
    h) print_help; exit 0 ;;
    *) print_help; exit 1 ;;
  esac
done

# Build bpftrace program
if [ "$TRACE_ALL" -eq 1 ]; then
  BT_PROG='tracepoint:syscalls:sys_enter_* { @[probe] = count(); }'
else
  # escape any quotes in COMM just in case
  ESC_COMM="${COMM//\"/\\\"}"
  BT_PROG="tracepoint:syscalls:sys_enter_* /comm == \"${ESC_COMM}\"/ { @[probe] = count(); }"
fi

echo "bpftrace program:"
echo "  $BT_PROG"
echo
echo "Output will be written to: $OUTFILE"
if [ "$DURATION" -gt 0 ]; then
  echo "Duration: ${DURATION}s (will attempt to stop automatically)"
else
  echo "Running interactively — press Ctrl-C to stop and dump results to file."
fi
echo

# Run bpftrace via sudo and redirect both stdout+stderr to the outfile
# We run it in background so we can optionally stop it after $DURATION.
# Note: the background PID is the sudo process; we'll send SIGINT to that PID to
# allow bpftrace to print the aggregation summary.
sudo sh -c "echo 'Starting bpftrace (you may be prompted for your password)...' >&2"
sudo bash -c "echo '--- bpftrace started at: ' \$(date) > \"$OUTFILE\""  # header

# Start bpftrace in background
sudo bpftrace -e "$BT_PROG" >> "$OUTFILE" 2>&1 &

BPFTRACE_PID=$!
echo "bpftrace started (pid: $BPFTRACE_PID). Output appended to $OUTFILE"

if [ "$DURATION" -gt 0 ]; then
  # Sleep then send SIGINT to bpftrace (so it prints the aggregated table)
  sleep "$DURATION"
  echo "Time is up — attempting to stop bpftrace (pid $BPFTRACE_PID) with SIGINT..."
  # try with sudo (PID is for the sudo-launched process)
  sudo kill -INT "$BPFTRACE_PID" 2>/dev/null || kill -INT "$BPFTRACE_PID" 2>/dev/null || true
  # wait for process to exit
  wait "$BPFTRACE_PID" 2>/dev/null || true
  echo "Stopped. Results are in $OUTFILE"
else
  # Interactive: wait for user to Ctrl-C. We trap SIGINT to notify user where results are stored.
  trap 'echo; echo "Interrupted by user. If bpftrace is still running, press Ctrl-C again to force-quit."; echo "Aggregation (if produced) will be in '"$OUTFILE"'"; exit 130' INT
  wait "$BPFTRACE_PID"
fi
