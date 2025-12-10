# Ext4

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

```bash
cat /proc/kallsyms | awk '$2 ~ /^[Tt]$/ && $3 ~ /^ext4_/ { if(!seen[$3]++) print $1, $3 }'
```

## Challenges

1. LTTng ABI conflict with some of the tracepoints. Specifically, tracepoints that use complex data types which are not supported by LTTng.
2. Running processes in different groups to minimize noise in the logs.
3. Creating different workloads to trigger Ext4 features (e.g., journaling, failure recovery, etc.).
4. Mapping kernel stack addresses to functions or symbols.
