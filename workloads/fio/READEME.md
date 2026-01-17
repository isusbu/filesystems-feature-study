# FIO

```sh
sudo -g ext4_grp fio "<config>.fio"
```

```sh
sudo -g ext4_grp fio ./workloads/fio/sequential_write.fio
sudo -g ext4_grp fio ./workloads/fio/random_write.fio
sudo -g ext4_grp fio ./workloads/fio/journaling.fio
sudo -g ext4_grp fio ./workloads/fio/fsync.fio
sudo -g ext4_grp fio ./workloads/fio/fallocate.fio
sudo -g ext4_grp fio ./workloads/fio/mixed_io.fio
sudo -g ext4_grp fio ./workloads/fio/truncate.fio
sudo -g ext4_grp fio ./workloads/fio/zero_write.fio
```
