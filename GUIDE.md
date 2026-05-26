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

## extent

To enable this feature, run:

```sh
sudo mkfs.ext4 -O ^extent,^64bit /dev/sdb

# mount to a point
sudo mkdir /mnt/sdb
sudo mount /dev/sdb /mnt/sdb

# validate
sudo tune2fs -l $(findmnt -n -o SOURCE --target /mnt/sdb) | grep extent
```

Create a target directory:

```sh
sudo mkdir /mnt/sdb/text
sudo chown -R $USER:$(id -gn) /mnt/sdb/text
```

Finally, execute `fio` workload:

```sh
fio --directory=/mnt/sdb/test ...
```
