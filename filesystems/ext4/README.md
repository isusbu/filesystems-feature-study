# Ext4

Setup a target disk for FIO test.

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

```bash
cd ~
sudo umount /mnt/ext4test
rm -rf /mnt/ext4test

rm ext4_test.img
```

Setup a target disk for tracing logs.

```bash
# make a 10GB empty image file
dd if=/dev/zero of=tracings.img bs=1M count=10240

# format it as XFS
mkfs.xfs tracings.img

# make a mount point
mkdir /mnt/tracings

# mount it using a loop device
sudo mount -o loop tracings.img /mnt/tracings
```

```bash
cd ~
sudo umount /mnt/tracings
rm -rf /mnt/tracings

rm tracings.img
```

Run this command to find the Ext4 kernel probes. 

```bash
cat /proc/kallsyms | awk '$2 ~ /^[Tt]$/ && $3 ~ /^ext4_/ { if(!seen[$3]++) print $3 }' > kprobes.txt
```

Create a group and replace the group id inside lttng script.

```bash
sudo groupadd fio_grp
getent group fio_grp
# fio_grp:x:1001:

sudo -g fio_grp ./fio.sh
```

## Challenges

1. LTTng ABI conflict with some of the tracepoints. Specifically, tracepoints that use complex data types which are not supported by LTTng.
    - Fixed by using kernel probes
    - Targeting 883 probes of Ext4 (only 10 failed to hook, 1.2% missing rate)
2. Running processes in different groups to minimize noise in the logs.
    - By using the group id, we can label and filter logs
3. Creating different workloads to trigger Ext4 features (e.g., journaling, failure recovery, etc.).
4. Mapping kernel stack addresses to functions or symbols.
5. Large volume of tracing results to parse (1 GB for only ext4 hit and 8 GB for callstack).
6. Tracer discarded 220,000 events when tracing with callstack option.
    - Even by enabling kstack tracing for only ext4 hit functions
7. Tracing results different even using the same test cases.
