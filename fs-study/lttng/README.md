# LTTng

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

To enable LTTng, after installing it, follow these instructions.

```bash
# to trace syscalls, LTTng needs a session (a daemon), the output will be stored in the given address
sudo lttng create syscalls-session --output /tmp/lttng-traces-100

# now we would add context that we want to be included in tracing logs
sudo lttng add-context --kernel --type vpid
sudo lttng add-context --kernel --type vtid
sudo lttng add-context --kernel --type procname
sudo lttng add-context --kernel --type pid
sudo lttng add-context --kernel --type ppid
sudo lttng add-context --kernel --type callstack-kernel
sudo lttng add-context --kernel --type callstack-user

# then we pass whatever we want to trace, in this case all syscalls
sudo lttng enable-event --kernel --all --syscall

# next we start our lttng session (non-blocking operation)
sudo lttng start

# after we are done, we stop our session
sudo lttng stop
```

After that we use `babeltrace2` to export our logs into a text-based format file.

```bash
sudo babeltrace2 /tmp/lttng-traces-100 > trace.txt
```

Now we can simply pass this output to any analysis script. In this case we use a simple python script.

```bash
python3 lttng_syscall_stats.py trace.txt
```

To list all kernel syscalls that are being traced, you can run:

```bash
sudo lttng list --kernel --syscall
```
