# NFS

## Drivers

Setup a target disk for workloads test (NFS).

## Setup NFS server (once)

```bash
# install tools if needed
sudo apt-get install -y nfs-kernel-server nfs-common

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
