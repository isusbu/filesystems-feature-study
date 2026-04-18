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

# load your metadata if it exists
if [ -f "/tmp/trace_metadata.env" ]; then
    source /tmp/trace_metadata.env
fi

# tracing parameters
# if FSTYP is not set, default to ext4
FS=${FSTYP:-ext4}
GROUP_ID=1002
ENABLE_KSTACK=0 # 0 disable, 1 enable

SUFFIX=$1
SESSION_NAME="${FS}-session-${SUFFIX}"

# create the output directory for the session
STORAGE_DIR="/tmp/lttng-tmp" # replaced with old path to increase storage speed "/mnt/gpfs/fs-study"
OUTPUT_DIR="${STORAGE_DIR}/${SESSION_NAME}"
mkdir -p "$OUTPUT_DIR"

# lttng tracing output directory
SESSION_DIR="${OUTPUT_DIR}/lttng-traces"
mkdir -p "$SESSION_DIR"

# read kernel probes for tracing from a target file
KPROBE_FILE_PATH="filesystems/${FS}/kprobes.txt"
if [ ! -f "$KPROBE_FILE_PATH" ]; then
    echo "missing file: $KPROBE_FILE_PATH"
    exit 1
fi

# create the lttng session
lttng create "$SESSION_NAME" -o "$SESSION_DIR"

# create the channel for tracing
lttng enable-channel --kernel channel0 \
  --subbuf-size=512M \
  --num-subbuf=2

# context needed for tracing
lttng add-context --kernel --type procname
lttng add-context --kernel --type gid

if [ "$ENABLE_KSTACK" -ne 0 ]; then
    # enable callstack tracing on command
    lttng add-context --kernel --type callstack-kernel
fi

# remove existing files and create new ones
rm -f ${OUTPUT_DIR}/failed.txt ${OUTPUT_DIR}/hooked.txt && touch ${OUTPUT_DIR}/failed.txt ${OUTPUT_DIR}/hooked.txt

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
        echo "$tp" >> ${OUTPUT_DIR}/failed.txt
    else
        echo "$tp" >> ${OUTPUT_DIR}/hooked.txt
    fi
done < "$KPROBE_FILE_PATH"

lttng track --kernel --session="$SESSION_NAME" --gid="$GROUP_ID"

# move the failed and hooked files to the permanent session directory
GPFS_PATH="/mnt/gpfs/fs-study"
GPFS_OUTPUT_DIR="${GPFS_PATH}/${SESSION_NAME}"
mkdir -p "$GPFS_OUTPUT_DIR"

cp "${OUTPUT_DIR}/failed.txt" "$GPFS_OUTPUT_DIR/"
cp "${OUTPUT_DIR}/hooked.txt" "$GPFS_OUTPUT_DIR/"
echo "failed and hooked probe files copied to: $GPFS_OUTPUT_DIR"

echo "session built."
echo "tracing output will be saved to: $SESSION_DIR"
echo "probes for tracing: see ${OUTPUT_DIR}/hooked.txt"
echo "failed hooks: see ${OUTPUT_DIR}/failed.txt"
echo "start: ./lttng/start.sh ${SUFFIX}"
echo "stop: ./lttng/stop.sh ${SUFFIX}"
echo "cleanup: ./lttng/cleanup.sh ${SUFFIX}"
echo "happy life!"
