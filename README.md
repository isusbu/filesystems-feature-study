# File systems Feature Study

## LTTng

To run LTTng tracer you need to have three things:

1. A place to store tracing logs (`/mnt/gpfs/fs-study` mounted with NFS).
2. A group id to run your workloads within specific group.
3. An LTTng session.

To start a session, run the `lttng/init.sh <NAME>` script. This will export your logs to `/mnt/gpfs/fs-study/ext4-session-<NAME>`. Then run `lttng/start.sh <NAME>` to start tracer.

Once your done running your worklaods, execute `lttng/stop.sh <NAME>`. After that run `lttng/cleanup.sh <NAME>` to export your logs in `/mnt/gpfs/fs-study/ext4-session-<NAME>.out`.

## Tests

Run your workloads with ext4_grp (with GID 1002), so you can filter your logs after that.

```sh
ubuntu@dhcp159:/$ getent group ext4_grp
ext4_grp:x:1002:

# running dbench for instance
ubuntu@dhcp159:/$ sudo -g ext4_grp dbench 16 -D /mnt/ext4test -t 10
```

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
