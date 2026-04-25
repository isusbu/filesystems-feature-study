# F2FS

F2fs file system has 40 feature flags. By default, 21 of them are enabled.

```txt
01. background_gc (enabled by default)
02. disable_roll_forward (enabled by default)
03. norecovery (enabled by default)
04. discard/nodiscard
05. no_heap (enabled by default)
06. nouser_xattr (enabled by default)
07. noacl (enabled by default)
08. disable_ext_identify (enabled by default)
09. inline_xattr (enabled by default)
10. inline_data (enabled by default)
11. inline_dentry (enabled by default)
12. flush_merge
13. nobarrier (enabled by default)
14. fastboot
15. extent_cache (enabled by default)
16. data_flush (enabled by default)
17. reserve_root (enabled by default)
18. fault_injection
19. usrquota
20. grpquota
21. prjquota
22. quota
32. whint_mode
33. alloc_mode (enabled by default)
34. fsync_mode (enabled by default)
35. test_dummy_encryption
36. checkpoint (enabled by default)
37. compress_algorithm (enabled by default)
38. compress_log_size (enabled by default)
39. compress_extension (enabled by default)
40. io_bits (enabled by default)
```

Reference: [https://www.kernel.org/doc/Documentation/filesystems/f2fs.txt](https://www.kernel.org/doc/Documentation/filesystems/f2fs.txt)

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
