# NFS

## Drivers

Setup a target disk for workloads test (NFS).

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

# make a client mount point
sudo mkdir -p /mnt/nfstest

# mount NFS export
sudo mount -t nfs -o vers=4 127.0.0.1:/srv/nfstest /mnt/nfstest
```

```bash
cd ~
sudo umount /mnt/nfstest
sudo rm -rf /mnt/nfstest

sudo rm -f /etc/exports.d/nfstest.exports
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

sudo rm -rf /srv/nfstest
```
