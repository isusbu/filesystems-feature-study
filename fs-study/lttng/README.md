# LTTng

To enable LTTng, after installing it, follow these instructions.

```bash
# to trace syscalls, LTTng needs a session (a daemon), the output will be stored in the given address
sudo lttng create syscalls-session --output /tmp/lttng-traces-100
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
