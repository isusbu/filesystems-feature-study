#!/usr/bin/env sh

# setup_lttng.sh
# This script sets up an LTTng tracing session for all system calls,
# including various context information, and stores the traces in /tmp/lttng-traces-100.

sudo lttng create syscalls-session --output /tmp/lttng-traces-100

sudo lttng add-context --kernel --type vpid
sudo lttng add-context --kernel --type vtid
sudo lttng add-context --kernel --type procname
sudo lttng add-context --kernel --type pid
sudo lttng add-context --kernel --type ppid
sudo lttng add-context --kernel --type callstack-kernel
sudo lttng add-context --kernel --type callstack-user

# sudo lttng enable-event --kernel --all --syscall
# dropping LTTng syscalls
sudo lttng enable-event --kernel --all --syscall --filter 'procname != "lttng-consumerd" && procname != "lttng-sessiond"'
