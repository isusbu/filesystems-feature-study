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

# check for babeltrace2 install
if cexists "babeltrace2"; then
    echo "babeltrace2 found!"
else
    echo "please install babeltrace2!"
    exit 1
fi

# tracing parameters
FS=ext4
SUFFIX=$1
SESSION_NAME="ext4-session-${SUFFIX}"
OUTPUT_DIR="/mnt/gpfs/fs-study/${SESSION_NAME}"

# read kernel probes for tracing from a target file
KPROBE_FILE_PATH="filesystems/${FS}/kprobes.txt"
if [ ! -f "$KPROBE_FILE_PATH" ]; then
    echo "missing file: $KPROBE_FILE_PATH"
    exit 1
fi

# export the tracing results
babeltrace2 "/mnt/gpfs/fs-study/${SESSION_NAME}" > "/mnt/gpfs/fs-study/${SESSION_NAME}.out"
# rm -rf "${OUTPUT_DIR}"

# run the logparser
lp -file "/mnt/gpfs/fs-study/${SESSION_NAME}.out" -init "${KPROBE_FILE_PATH}"

# destroy the session
lttng destroy "${SESSION_NAME}"
