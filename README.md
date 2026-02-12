# File systems Feature Study

Our goal is to measure file systems functions usage under various workloads.

## LTTng (our tracer)

To run LTTng tracer you need to have three things:

1. A place to store tracing logs (`/mnt/gpfs/fs-study` mounted with NFS).
2. A group id to run your workloads within specific group, so that you can filter your workload logs.
3. An LTTng user-level session.

NOTE: We store our logs in a 1TB GPFS storage mounted to the VM using NFS.

### session

To start a session, run the `lttng/init.sh <NAME>` script. This will configure an LTTng user-level session to trace all kernel functions in `kprobes.txt`. Also, it will export your tracing logs to `/mnt/gpfs/fs-study/ext4-session-<NAME>`. 

### tracer

Once you have your session (check by running `sudo lttng list`), then run `lttng/start.sh <NAME>` to start LTTng tracer. This will run the tracer in kernel level, so the VM might start slowing down if you let it run for too long.

Once your done running your worklaods, execute `lttng/stop.sh <NAME>` to stop the tracer in kernel level. After that run `lttng/cleanup.sh <NAME>` to cleanup and export your logs (CTF format) to `/mnt/gpfs/fs-study/ext4-session-<NAME>.out` in human readable format.

An example output:

```txt
[16:49:42.175248695] (+0.000002264) dhcp157.fsl.cs.sunysb.edu ext4_buffered_write_iter: { cpu_id = 0 }, { procname = "kworker/u5:4", gid = 0 }, { ip = 0xFFFFFFFFA0FEE730 }
[16:49:42.175249914] (+0.000001219) dhcp157.fsl.cs.sunysb.edu ext4_generic_write_checks: { cpu_id = 0 }, { procname = "kworker/u5:4", gid = 0 }, { ip = 0xFFFFFFFFA0FED9A0 }
[16:49:42.175250883] (+0.000000969) dhcp157.fsl.cs.sunysb.edu ext4_dirty_inode: { cpu_id = 0 }, { procname = "kworker/u5:4", gid = 0 }, { ip = 0xFFFFFFFFA1008720 }
```

## Tests

Run your workloads (or tests) with `ext4_grp` (GID 1002) group, so you can set a filter on lttng logs.

```sh
ubuntu@dhcp159:/$ getent group ext4_grp
ext4_grp:x:1002:

# running dbench for instance
ubuntu@dhcp159:/$ sudo -g ext4_grp dbench 16 -D /mnt/ext4test -t 10
```

### Loop Devices

Setup a target disk for workloads test (Ext4).

```bash
# make a 2GB empty image file
dd if=/dev/zero of=ext4_test.img bs=1M count=2048

# format it as Ext4
mkfs.ext4 ext4_test.img

# make a mount point
mkdir /mnt/ext4test

# mount it using a loop device
sudo mount -o loop ext4_test.img /mnt/ext4test
```
