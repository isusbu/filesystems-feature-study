#!/bin/bash

# check command existence
cexists() {
    command -v "$1" >/dev/null 2>&1
}

# Load your metadata if it exists
if [ -f "/tmp/trace_metadata.env" ]; then
    source /tmp/trace_metadata.env
fi


# tracing parameters
# if FSTYP is not set, default to ext4
FS=${FSTYP:-ext4}

# check for lttng install
if cexists "lttng"; then
    echo "lttng found!"
else
    echo "please install lttng!"
    exit 1
fi

# tracing parameters
SUFFIX=$1
SESSION_NAME="${FS}-session-${SUFFIX}"

lttng stop $SESSION_NAME

# rotate the trace to flush the buffers and make the trace data available for analysis
out=$(lttng rotate $SESSION_NAME)
echo "rotate output: $out"
