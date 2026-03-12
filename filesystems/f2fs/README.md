# F2FS

## Drivers

Setup a target disk for workloads test (F2FS).

```bash
# install tools if needed
sudo apt-get install -y f2fs-tools

# make a 2GB empty image file
dd if=/dev/zero of=f2fs_test.img bs=1M count=2048

# format it as F2FS
mkfs.f2fs f2fs_test.img

# make a mount point
mkdir /mnt/f2fstest

# mount it using a loop device
sudo mount -o loop f2fs_test.img /mnt/f2fstest
```

```bash
cd ~
sudo umount /mnt/f2fstest
rm -rf /mnt/f2fstest

rm f2fs_test.img
```
