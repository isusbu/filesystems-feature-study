#!/bin/bash

# check command existence
cexists() {
    command -v "$1" >/dev/null 2>&1
}

# check for lttng & babeltrace2 install
if cexists "lttng"; then
    echo "lttng found!"
else
    echo "please install lttng!"
    exit 1
fi

if ! cexists "babeltrace2"; then
    echo "please install babeltrace2!"
    exit 1
fi

# load your metadata if it exists
if [ -f "/tmp/trace_metadata.env" ]; then
    source /tmp/trace_metadata.env
fi

# tracing parameters
# if FSTYP is not set, default to ext4
FS=${FSTYP:-ext4}

SUFFIX=$1
OUTPUT_NAME=${2:-logs}
SESSION_NAME="${FS}-session-${SUFFIX}"

STORAGE_DIR="/mnt/gpfs/fs-study"
OUTPUT_DIR="${STORAGE_DIR}/${SESSION_NAME}"
SESSION_DIR="${OUTPUT_DIR}/lttng-traces"

# stop the lttng session
lttng stop $SESSION_NAME

# rotate the trace to flush the buffers and make the trace data available for analysis
out=$(lttng rotate $SESSION_NAME)
echo "rotate output: $out"

# parse the output of the rotate command to get the path to the readable archive
archive_path=$(printf '%s\n' "$out" | sed -n 's/.* is now readable at \(.*\)$/\1/p' | tail -n 1)

if [ -z "$archive_path" ] || [ ! -d "$archive_path" ]; then
    echo "could not determine readable archive path from rotate output"
    exit 1
fi

# use babeltrace2 to convert the trace data to a human-readable format and save it to a file
OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}.out"
babeltrace2 "$archive_path" > "$OUTPUT_FILE"
echo "babeltrace2 output saved to: $OUTPUT_FILE"

# read kernel probes for tracing from a target file
KPROBE_FILE_PATH="filesystems/${FS}/kprobes.txt"
if [ ! -f "$KPROBE_FILE_PATH" ]; then
    echo "missing file: $KPROBE_FILE_PATH"
    exit 1
fi

# run the logparser
lp -file "$OUTPUT_FILE" -init "${KPROBE_FILE_PATH}"
echo "logparser output saved to: ${OUTPUT_DIR}/${OUTPUT_NAME}.parsed"
