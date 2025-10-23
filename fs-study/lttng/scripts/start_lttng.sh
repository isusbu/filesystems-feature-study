#!/usr/bin/env sh

# session name
SESSION="all-syscalls-session"

# output directory
OUTPUT="/tmp"

# configuration rotation
ENABLE_ROTATION="yes"
ROTATION_SIZE="200M"

# the following contexts are useful for analyzing syscall stacks, but may add overhead
ENABLE_STACKS="no"

## load configs from .config.env if it exists
CFG_FILE="$(pwd)/.config.env"
if [ -f "${CFG_FILE}" ]; then
  . "${CFG_FILE}"
fi

# setup_lttng.sh
# This script sets up an LTTng tracing session for all system calls,
# including various context information, and stores the traces.
sudo lttng create syscalls-session-"${SESSION}" --output "${OUTPUT}/lttng-traces-${SESSION}"

# create a channel based on the machine's page size
sudo lttng enable-channel --kernel channel0 \
  --subbuf-size=8M \
  --num-subbuf=16

# add context information to the events
sudo lttng add-context --kernel --type vpid
sudo lttng add-context --kernel --type vtid
sudo lttng add-context --kernel --type procname
sudo lttng add-context --kernel --type pid
sudo lttng add-context --kernel --type ppid

# the following contexts are useful for analyzing syscall stacks, but may add overhead
if [ "${ENABLE_STACKS}" = "yes" ]; then
  echo "Enabling kernel and user callstack contexts."
  sudo lttng add-context --kernel --type callstack-kernel
  sudo lttng add-context --kernel --type callstack-user
fi

# enable all syscall events
# NOTE: this includes the LTTng internal syscalls as well
# so make sure to run the stop_lttng.sh script to filter them out.
sudo lttng enable-event --kernel --all --syscall --channel=channel0

# ensure all PIDs are traced
sudo lttng track --kernel --pid --all

# enable rotation based on size
if [ "${ENABLE_ROTATION}" = "yes" ]; then
  echo "Enabling rotation with size ${ROTATION_SIZE}."
  sudo lttng enable-rotation --session syscalls-session-"${SESSION}" --size "${ROTATION_SIZE}"
fi

# start the tracing session
sudo lttng start syscalls-session-"${SESSION}"
echo "LTTng tracing session 'syscalls-session-${SESSION}' started."
