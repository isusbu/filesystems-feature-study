# MLPerf Storage

Official GitHub repository: [https://github.com/mlcommons/storage](https://github.com/mlcommons/storage)

> NOTE: Make sure that your CPU supports avx instructions to work with tensorflow.

## Commands

Data generation:

```sh
sudo -g ext4_grp -E ./mlpstorage training datagen --model unet3d --data-dir /mnt/sdb/mlperf/ --object -np 10
sudo -g ext4_grp -E ./mlpstorage training datagen --model resnet50 --data-dir /mnt/sdb/mlperf/ --object -np 10
```

Training benchmark:

```sh
sudo -g ext4_grp -E ./mlpstorage training run --model unet3d --client-host-memory-in-gb 1 --num-accelerators 1 --accelerator-type a100 --data-dir /mnt/sdb/mlperf --object --allow-run-as-root
sudo -g ext4_grp -E ./mlpstorage training run --model unet3d --client-host-memory-in-gb 1 --num-accelerators 1 --accelerator-type a100 --data-dir /mnt/sdb/mlperf --file --allow-run-as-root
sudo -g ext4_grp -E ./mlpstorage training run --model unet3d --client-host-memory-in-gb 1 --num-accelerators 1 --accelerator-type h100 --data-dir /mnt/sdb/mlperf --object --allow-run-as-root
sudo -g ext4_grp -E ./mlpstorage training run --model unet3d --client-host-memory-in-gb 1 --num-accelerators 1 --accelerator-type h100 --data-dir /mnt/sdb/mlperf --file --allow-run-as-root
sudo -g ext4_grp -E ./mlpstorage training run --model resnet50 --client-host-memory-in-gb 1 --num-accelerators 1 --accelerator-type a100 --data-dir /mnt/sdb/mlperf --object --allow-run-as-root
sudo -g ext4_grp -E ./mlpstorage training run --model resnet50 --client-host-memory-in-gb 1 --num-accelerators 1 --accelerator-type a100 --data-dir /mnt/sdb/mlperf --file --allow-run-as-root
sudo -g ext4_grp -E ./mlpstorage training run --model resnet50 --client-host-memory-in-gb 1 --num-accelerators 1 --accelerator-type h100 --data-dir /mnt/sdb/mlperf --object --allow-run-as-root
sudo -g ext4_grp -E ./mlpstorage training run --model resnet50 --client-host-memory-in-gb 1 --num-accelerators 1 --accelerator-type h100 --data-dir /mnt/sdb/mlperf --file --allow-run-as-root
```
