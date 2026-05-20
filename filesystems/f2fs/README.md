# F2FS

| # | Option | Default | Notes |
|---|---|:---:|---|
| 01 | `background_gc=%s` | on | Values: `on` / `off` / `sync` |
| 02 | `gc_merge` | off | Lets background GC handle foreground GC requests |
| 03 | `nogc_merge` | — | Disables gc_merge |
| 04 | `disable_roll_forward` | off | Disables roll-forward recovery |
| 05 | `norecovery` | off | Disables roll-forward; forces read-only mount |
| 06 | `discard` / `nodiscard` | discard | Issues TRIM/discard on segment clean |
| 07 | `heap` / `no_heap` | — | **Deprecated** |
| 08 | `nouser_xattr` | off | Disables extended user attributes (xattr on by default) |
| 09 | `noacl` | off | Disables POSIX ACL (acl on by default) |
| 10 | `active_logs=%u` | 6 | Supported values: 2, 4, 6 |
| 11 | `disable_ext_identify` | off | Disables mkfs extension list (cold file awareness) |
| 12 | `inline_xattr` | on | Enables inline xattrs |
| 13 | `noinline_xattr` | — | Disables inline xattrs |
| 14 | `inline_xattr_size=%u` | — | Configures inline xattr size |
| 15 | `inline_data` | on | Small files (<~3.4k) stored in inode block |
| 16 | `noinline_data` | — | Disables inline_data |
| 17 | `inline_dentry` | on | New directory entries written into inode block |
| 18 | `noinline_dentry` | — | Disables inline_dentry |
| 19 | `flush_merge` | off | Merges concurrent cache_flush commands |
| 20 | `nobarrier` | off | Skips cache_flush; use only on non-volatile storage |
| 21 | `barrier` | on | Allows cache_flush commands (counterpart to nobarrier) |
| 22 | `fastboot` | off | Reduces mount time at the cost of normal performance |
| 23 | `extent_cache` | on | rb-tree extent cache for logical-to-physical mapping |
| 24 | `noextent_cache` | — | Explicitly disables extent_cache |
| 25 | `data_flush` | off | Flushes data before checkpoint for regular files/symlinks |
| 26 | `reserve_root=%d` | 12.5% | Reserved space (unit: 4KB) for privileged uid/gid |
| 27 | `fault_injection=%d` | off | Enables fault injection at specified rate |
| 28 | `fault_type=%d` | — | Configures fault injection type bitmask; requires fault_injection |
| 29 | `mode=%s` | adaptive | Values: `adaptive` / `lfs` / `fragment:segment` / `fragment:block` |
| 30 | `usrquota` | off | Plain user disk quota accounting |
| 31 | `grpquota` | off | Plain group disk quota accounting |
| 32 | `prjquota` | off | Plain project disk quota accounting |
| 33 | `quota` | off | Alias for plain user disk quota accounting |
| 34 | `noquota` | — | Disables all plain quota options |
| 35 | `whint_mode=%s` | off | Write hint mode: `off` / `user-based` / `fs-based` |
| 36 | `alloc_mode=%s` | default | Block allocation policy: `default` / `reuse` |
| 37 | `fsync_mode=%s` | posix | fsync policy: `posix` / `strict` / `nobarrier` |
| 38 | `test_dummy_encryption[=%s]` | off | Fake fscrypt context for xfstests; values: `v1` / `v2` |
| 39 | `checkpoint=%s[:%u[%]]` | enable | Set `disable` to turn off checkpointing |
| 40 | `checkpoint_merge` | off | Kernel daemon merges concurrent checkpoint requests |
| 41 | `nocheckpoint_merge` | — | Disables checkpoint_merge |
| 42 | `compress_algorithm=%s[:%d]` | lzo | Algorithm: `lzo` / `lz4` / `zstd` / `lzo-rle`; optional level |
| 43 | `compress_log_size=%u` | 2 (16KB) | Compress cluster size = 4KB × (1 << %u); minimum 16KB |
| 44 | `compress_extension=%s` | — | File extensions to compress (use `*` for all) |
| 45 | `nocompress_extension=%s` | — | File extensions to exclude from compression |
| 46 | `compress_chksum` | off | Verifies checksum of raw data in compressed clusters |
| 47 | `compress_mode=%s` | fs | Compression mode: `fs` (automatic) / `user` (manual via ioctl) |
| 48 | `compress_cache` | off | Uses inode address space to cache compressed blocks |
| 49 | `inlinecrypt` | off | Uses blk-crypto for encryption instead of filesystem-layer |
| 50 | `atgc` | off | Age-threshold garbage collection for better hot/cold separation |
| 51 | `age_extent_cache` | off | rb-tree age extent cache for data block temperature hints |
| 52 | `noage_extent_cache` | — | Explicitly disables age_extent_cache |
| 53 | `discard_unit=%s` | block | Discard unit: `block` / `segment` / `section` |
| 54 | `memory=%s` | normal | Memory mode: `normal` / `low` |
| 55 | `io_bits=%u` | — | Bit size of write I/O requests; requires `mode=lfs` |

Reference: [https://www.kernel.org/doc/Documentation/filesystems/f2fs.txt](https://www.kernel.org/doc/Documentation/filesystems/f2fs.txt)

## Drivers

Setup a target disk for workloads test (F2FS).

```bash
# install tools if needed
sudo apt-get install -y f2fs-tools

# make a 2GB empty image file
dd if=/dev/zero of=f2fs_test.img bs=1M count=2048

# format it as F2FS
mkfs.f2fs f2fs_test.img -O encrypt,extra_attr,project_quota,inode_checksum,flexible_inline_xattr,quota,inode_crtime,lost_found,verity,sb_checksum,casefold,compression

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
