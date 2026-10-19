#!/bin/bash
# Replay a Janus queue on the real kernel in time windows, one LTTng session per batch.
# Each session starts from a fresh lttng-sessiond: destroying a session can leave
# lttng-consumerd dead, and every later session then records nothing.
#
#   sudo bash workloads/janus/run_replay_windows.sh --fs ext4 --seed ext4-00.image \
#        --queue /srv/janus_replay/fuzz_out_ext4_00/ext4_00/queue --prog /replay/prog_ext4_00 \
#        --tag e00 --window 30 --windows 6 --batch 500 --pause 3 --pause-rejected 1 \
#        --container janus-ext4
#
# Sessions: <fs>-session-<tag>_base, <fs>-session-<tag>_w<W>_b<K> (W = window index, 1-based).
# Run from the filesystems-feature-study folder.
set -u
FS=ext4; SEED=ext4-00.image; Q=""; PROG=/replay/prog_ext4_00; TAG=e00
WIN=30; NWIN=6; BATCH=500; PAUSE=3; PAUSE_REJ=1; C=janus-ext4; SKIP_BASE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fs) FS=$2; shift 2 ;;          --seed) SEED=$2; shift 2 ;;
    --queue) Q=$2; shift 2 ;;        --prog) PROG=$2; shift 2 ;;
    --tag) TAG=$2; shift 2 ;;        --window) WIN=$2; shift 2 ;;
    --windows) NWIN=$2; shift 2 ;;   --batch) BATCH=$2; shift 2 ;;
    --pause) PAUSE=$2; shift 2 ;;    --pause-rejected) PAUSE_REJ=$2; shift 2 ;;
    --container) C=$2; shift 2 ;;
    --skip-baseline) SKIP_BASE=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option $1"; exit 1 ;;
  esac
done
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
[ -n "$Q" ] || { echo "--queue is required"; exit 1; }
[ -f lttng/init.sh ] || { echo "run from the filesystems-feature-study folder"; exit 1; }

WL="$(dirname "$(readlink -f "$0")")/lttng_workload.sh"
LOG=/srv/janus_replay/replay_${TAG}_$(date +%Y%m%d_%H%M).log
PREV=""
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

fail() { log "STOP: $*"; exit 1; }

session() {   # $1 short name, rest passed to lttng_workload.sh
  local name=$1; shift
  local full="${FS}-session-${name}"
  [ -n "$PREV" ] && FSTYP=$FS ./lttng/cleanup.sh "$PREV" >/dev/null 2>&1
  killall -9 lttng-sessiond lttng-consumerd 2>/dev/null; sleep 2
  lttng-sessiond --daemonize; sleep 3
  log "=== $name ==="
  FSTYP=$FS ./lttng/init.sh "$name" >/dev/null 2>&1 || fail "init $name"
  FSTYP=$FS ./lttng/start.sh "$name" >/dev/null 2>&1 || fail "start $name"
  bash "$WL" "$@" --session "$full" >> "$LOG" 2>&1
  local rc=$?
  grep -E "selected|check|ERROR|done:" <(tail -n 200 "$LOG") | tail -4
  [ $rc = 0 ] && ! tail -3 "$LOG" | grep -q ERROR || fail "workload $name"
  log "$name $(lttng list "$full" | grep -o 'Discarded event records: [0-9]*')"
  FSTYP=$FS ./lttng/stop.sh "$name" >> "$LOG" 2>&1
  tail -5 "$LOG" | grep -q "successfully copied" || fail "stop $name (counts not copied)"
  PREV=$name
}

log "start fs=$FS tag=$TAG kernel=$(uname -r) probes=$(wc -l < filesystems/$FS/kprobes.txt) queue=$Q window=${WIN}min x$NWIN"
COMMON=(--fs "$FS" --seed "$SEED" --container "$C" --pause "$PAUSE" --pause-rejected "$PAUSE_REJ")
[ "$SKIP_BASE" = 1 ] || session "${TAG}_base" --mode baseline --prog "$PROG" "${COMMON[@]}"

for ((w=1; w<=NWIN; w++)); do
  from=$(( (w-1)*WIN )); to=$(( w*WIN ))
  total=$(bash "$WL" --mode janus --queue "$Q" --from-min $from --to-min $to --count 0 "${COMMON[@]}" 2>/dev/null \
          | sed -n 's/^selected \([0-9]*\) inputs.*/\1/p')
  log "window $w (${from}-${to} min): ${total:-0} inputs"
  for ((k=0; k<${total:-0}; k+=BATCH)); do
    session "${TAG}_w${w}_b${k}" --mode janus --queue "$Q" --from-min $from --to-min $to \
            --start $k --count $BATCH "${COMMON[@]}"
  done
done

[ -n "$PREV" ] && FSTYP=$FS ./lttng/cleanup.sh "$PREV" >/dev/null 2>&1
log "all done"
