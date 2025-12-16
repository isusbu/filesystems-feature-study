#!/bin/sh

# check command existence
cexists() {
    command -v "$1" >/dev/null 2>&1
}

# check for lttng install
if cexists "lttng"; then
    echo "lttng found!"
else
    echo "please install lttng!"
    exit 1
fi

# tracing parameters
SUFFIX=$1
SESSION_NAME="ext4-session-${SUFFIX}"
OUTPUT_DIR="/mnt/tracings/${SESSION_NAME}"

# read kernel probes for tracing from a target file
KPROBE_FILE_PATH="kprobes.txt"
if [ ! -f "$KPROBE_FILE_PATH" ]; then
    echo "missing file: $KPROBE_FILE_PATH"
    exit 1
fi

# create the lttng session
lttng create "$SESSION_NAME" -o "$OUTPUT_DIR"

# create the channel for tracing
lttng enable-channel --kernel channel0 \
  --subbuf-size=8M \
  --num-subbuf=16

# context needed for tracing
lttng add-context --kernel --type procname
lttng add-context --kernel --type gid
lttng add-context --kernel --type callstack-kernel

# read probes line-by-line
while IFS= read -r tp; do
    # skip empty or commented lines
    case "$tp" in
        ""|\#*) continue ;;
    esac

    echo "Enabling kernel probe for: $tp"
    lttng enable-event --channel=channel0 --kernel --probe="$tp" "$tp"
    
    STATUS=$?
    if [ "$STATUS" -ne 0 ]; then
        echo "$tp" >> failed.txt
    else
        echo "$tp" >> hooked.txt
    fi
done < "$KPROBE_FILE_PATH"

echo "session built."
echo "probes for tracing: see hooked.txt"
echo "failed hooks: see failed.txt"
echo "run: sudo lttng start --session=$SESSION_NAME"
echo "execute your workload ..."
echo "run: sudo lttng stop --session=$SESSION_NAME"
echo "run: sudo lttng destroy --session=$SESSION_NAME"
echo "output at: $OUTPUT_DIR"
echo "use: babeltrace2 $OUTPUT_DIR"
echo "happy life!"
