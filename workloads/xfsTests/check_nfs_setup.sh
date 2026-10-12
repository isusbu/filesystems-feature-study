# this is needed only once
sudo apt-get install -y nfs-kernel-server nfs-common

# check for loop device
losetup
#our img is in /mnt


# check for server folders
ls /srv

