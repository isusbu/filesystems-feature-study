# NFS

By default all 12 features are enabled.

[https://man7.org/linux/man-pages/man5/nfs.5.html](https://man7.org/linux/man-pages/man5/nfs.5.html)

## Drivers

Setup a target disk for workloads test (NFS).

## Setup NFS server (once)

```bash
# install tools if needed
sudo apt-get install -y nfs-kernel-server nfs-common

# create a loop device for NFS server
sudo dd if=/dev/zero of=/mnt/nfs.img bs=1M count=4096
sudo mkfs.ext4 /mnt/nfs.img
sudo mkdir -p /srv/nfstest
sudo mount -o loop /mnt/nfs.img /srv/nfstest

# make a server-side export directory
sudo mkdir -p /srv/nfstest
sudo chown -R "$USER":"$USER" /srv/nfstest

# export only to localhost for local tracing tests
echo '/srv/nfstest 127.0.0.1(rw,sync,no_subtree_check,no_root_squash)' | sudo tee /etc/exports.d/nfstest.exports >/dev/null
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
```

## Setup mount points

```bash
# make a client mount point
sudo mkdir -p /mnt/nfstest

# mount NFS export
sudo mount -t nfs -o vers=4 127.0.0.1:/srv/nfstest /mnt/nfstest

# check
mount | grep nfs
# 127.0.0.1:/srv/nfstest on /mnt/nfstest type nfs4 (rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=127.0.0.1,local_lock=none,addr=127.0.0.1)
```

```bash
# cleanup
cd ~
sudo umount /mnt/nfstest
sudo rm -rf /mnt/nfstest

# server cleanup
sudo rm -f /etc/exports.d/nfstest.exports
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

sudo rm -rf /srv/nfstest
```
