#!/bin/bash

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

# Load your metadata if it exists
if [ -f "/tmp/trace_metadata.env" ]; then
    source /tmp/trace_metadata.env
fi


# tracing parameters
# if FSTYP is not set, default to ext4
FS=${FSTYP:-ext4}
SUFFIX=$1
SESSION_NAME="${FS}-session-${SUFFIX}"
OUTPUT_DIR="/mnt/gpfs/fs-study/${SESSION_NAME}" # our GPFS storage
GROUP_ID=1002
ENABLE_KSTACK=0 # 0 disable, 1 enable
LTTNG_DIR="/home/satche/filesystems-feature-study/lttng"

# read kernel probes for tracing from a target file
KPROBE_FILE_PATH="filesystems/${FS}/kprobes.txt"
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

if [ "$ENABLE_KSTACK" -ne 0 ]; then
    # enable callstack tracing on command
    lttng add-context --kernel --type callstack-kernel
fi

# cleanup
rm -f ${LTTNG_DIR}/failed.txt ${LTTNG_DIR}/hooked.txt && touch ${LTTNG_DIR}/failed.txt ${LTTNG_DIR}/hooked.txt

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
        echo "$tp" >> ${LTTNG_DIR}/failed.txt
    else
        echo "$tp" >> ${LTTNG_DIR}/hooked.txt
    fi
done < "$KPROBE_FILE_PATH"

lttng track --kernel --session="$SESSION_NAME" --gid="$GROUP_ID"

echo "session built."
echo "probes for tracing: see hooked.txt"
echo "failed hooks: see failed.txt"
echo "run: sudo lttng start $SESSION_NAME"
echo "execute your workload ..."
echo "run: sudo lttng stop $SESSION_NAME"
echo "run: sudo lttng destroy $SESSION_NAME"
echo "output at: $OUTPUT_DIR"
echo "use: babeltrace2 $OUTPUT_DIR"
echo "happy life!"
