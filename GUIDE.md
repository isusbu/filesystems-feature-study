# Mapping experiments

## encrypt

To enable this feature, run:

```sh
sudo mkfs.ext4 -O encrypt /dev/sdb

# mount to a point
sudo mkdir /mnt/sdb
sudo mount /dev/sdb /mnt/sdb

# validate
sudo tune2fs -l $(findmnt -n -o SOURCE --target /mnt/sdb) | grep encrypt
```

Enable fscrypt before running `fio`:

```sh
sudo fscrypt setup /mnt/sdb
```

Create a target directory, and enable encryption:

```sh
sudo mkdir /mnt/sdb/encrypt
sudo chown -R $USER:$(id -gn) /mnt/sdb/encrypt
fscrypt encrypt /mnt/sdb/encrypt
```

Finally, execute `fio` workload:

```sh
fio --directory=/mnt/sdb/encrypt ...
```

## large\_file

To disable this feature, run:

```sh
sudo mkfs.ext4 -O ^large_file

# mount to a point
sudo mkdir /mnt/sdb
sudo mount /dev/sdb /mnt/sdb

# validate
sudo tune2fs -l $(findmnt -n -o SOURCE --target /mnt/sdb) | grep large_file
```

Create a target directory:

```sh
sudo mkdir /mnt/sdb/lf
sudo chown -R $USER:$(id -gn) /mnt/sdb/lf
```

Finally, execute `fio` workload:

```sh
fio --directory=/mnt/sdb/lf ...
```
