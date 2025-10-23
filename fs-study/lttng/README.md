# LTTng

<!--
This one goes to my kind labmate Yifei who helped in LTTng configuration.
-->

LTTng is a tracing tool with low overhead and scalable for tracing system calls in a Linux machine.

## Installation

On an Ubuntu machine:

```bash
sudo apt-add-repository ppa:lttng/stable-2.13  # Or the latest stable version if different
sudo apt-get update
```

Installing core packages:

```bash
sudo apt-get install lttng-tools
sudo apt-get install lttng-modules-dkms
sudo apt-get install liblttng-ust-dev
```

Install Babeltrace for trace analysis:

```bash
sudo apt-get install babeltrace
sudo apt-get install python3-babeltrace
```

## Tracing example

To enable LTTng, after installing it, follow these instructions:

```bash
# set execute permission for lttng scripts
sudo chmod u+x scripts/start_lttng.sh scripts/stop_lttng.sh

# run the lttng start script
sudo scripts/start_lttng.sh

# stop the lttng after you are done
sudo scripts/stop_lttng.sh
```

### configuration

You can edit the values in `.config.env` to control your LTTng session.

```bash
# LTTng tracing configuration
# session name
SESSION="all-syscalls-session"

# output directory
OUTPUT="/tmp"

# configuration rotation
ENABLE_ROTATION="yes"
ROTATION_SIZE="200M"

# the following contexts are useful for analyzing syscall stacks, but may add overhead
ENABLE_STACKS="no"
```

### NOTE

To list all kernel syscalls that are being traced, you can run:

```bash
sudo lttng list --kernel --syscall
```

## Log Analysis

Now we can simply pass this output to any analysis script. In this case we use a simple python script.

```bash
# this script drops the syscalls made by any lttng processes, and counts the remaining syscalls (by default it reads trace.txt)
python3 lttng_syscall_stats.py example.trace.txt
```
