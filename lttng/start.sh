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

lttng start --session=$SESSION_NAME
