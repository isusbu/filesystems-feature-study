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
SUFFIX=$1
SESSION_NAME="ext4-session-${SUFFIX}"
OUTPUT_DIR="/mnt/tracings/${SESSION_NAME}"

# export the tracing results
babeltrace2 "/mnt/tracings/${SESSION_NAME}" > "${SESSION_NAME}"
rm -rf "${OUTPUT_DIR}"

# destroy the session
lttng destroy "${SESSION_NAME}"
