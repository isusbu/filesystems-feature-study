# Ext4

| # | Feature flag | Status | Default |
|---|---|---|:---:|
| 01 | `64bit` | enabled by default | ✓ |
| 02 | `bigalloc` | under development | — |
| 03 | `casefold` | disabled by default | — |
| 04 | `dir_index` | enabled by default | ✓ |
| 05 | `dir_nlink` | enabled by default | ✓ |
| 06 | `ea_inode` | disabled by default | — |
| 07 | `encrypt` | disabled by default | — |
| 08 | `ext_attr` | enabled by default | ✓ |
| 09 | `extent` | enabled by default | ✓ |
| 10 | `extra_isize` | enabled by default | ✓ |
| 11 | `filetype` | enabled by default | ✓ |
| 12 | `flex_bg` | enabled by default | ✓ |
| 13 | `has_journal` | enabled by default | ✓ |
| 14 | `huge_file` | enabled by default | ✓ |
| 15 | `inline_data` | not supported / experimental | — |
| 16 | `journal_dev` | special-purpose | — |
| 17 | `large_dir` | disabled by default | — |
| 18 | `large_file` | enabled by default | ✓ |
| 19 | `metadata_csum` | enabled by default | ✓ |
| 20 | `metadata_csum_seed` | disabled by default | — |
| 21 | `meta_bg` | disabled by default | — |
| 22 | `mmp` | disabled by default | — |
| 23 | `orphan_file` | disabled by default | — |
| 24 | `project` | disabled by default | — |
| 25 | `quota` | disabled by default | — |
| 26 | `resize_inode` | enabled by default | ✓ |
| 27 | `sparse_super` | enabled by default | ✓ |
| 28 | `sparse_super2` | disabled by default | — |
| 29 | `stable_inodes` | disabled by default | — |
| 30 | `uninit_bg` | disabled by default | — |

Reference: [https://man7.org/linux/man-pages/man5/ext4.5.html](https://man7.org/linux/man-pages/man5/ext4.5.html)

| # | Feature flag | Default | SQLite | Redis | AIStore |
|---|---|:---:|:---:|:---:|:---:|
| 01 | `64bit` | ✓ | — | — | ✓ |
| 02 | `bigalloc` | — | — | — | — |
| 03 | `casefold` | — | — | — | — |
| 04 | `dir_index` | ✓ | ✓ | ✓ | ✓ |
| 05 | `dir_nlink` | ✓ | — | — | — |
| 06 | `ea_inode` | — | — | — | — |
| 07 | `encrypt` | — | — | — | — |
| 08 | `ext_attr` | ✓ | — | — | ✓ |
| 09 | `extent` | ✓ | ✓ | ✓ | ✓ |
| 10 | `extra_isize` | ✓ | ✓ | ✓ | ✓ |
| 11 | `filetype` | ✓ | ✓ | ✓ | ✓ |
| 12 | `flex_bg` | ✓ | — | — | — |
| 13 | `has_journal` | ✓ | ✓ | ✓ | ✓ |
| 14 | `huge_file` | ✓ | — | — | ✓ |
| 15 | `inline_data` | experimental | — | — | — |
| 16 | `journal_dev` | special-purpose | — | — | — |
| 17 | `large_dir` | — | — | — | — |
| 18 | `large_file` | ✓ | ✓ | ✓ | ✓ |
| 19 | `metadata_csum` | ✓ | — | — | — |
| 20 | `metadata_csum_seed` | — | — | — | — |
| 21 | `meta_bg` | — | — | — | — |
| 22 | `mmp` | — | — | — | — |
| 23 | `orphan_file` | — | — | — | — |
| 24 | `project` | — | — | — | — |
| 25 | `quota` | — | — | — | — |
| 26 | `resize_inode` | ✓ | — | — | — |
| 27 | `sparse_super` | ✓ | — | — | — |
| 28 | `sparse_super2` | — | — | — | — |
| 29 | `stable_inodes` | — | — | — | — |
| 30 | `uninit_bg` | — | — | — | — |
| | **Minimum required** | | **5** | **5** | **8** |

## Drivers

Setup a target disk for workloads test (Ext4).

```bash
# make a 2GB empty image file
dd if=/dev/zero of=ext4_test.img bs=1M count=2048

# format it as Ext4
mkfs.ext4 ext4_test.img -O 64bit,casefold,dir_index,dir_nlink,ea_inode,encrypt,extent,extra_isize,filetype,flex_bg,has_journal,huge_file,large_dir,large_file,metadata_csum,orphan_file,project,quota,sparse_super,stable_inodes,uninit_bg,verity

# make a mount point
mkdir /mnt/ext4test

# mount it using a loop device
sudo mount -o loop ext4_test.img /mnt/ext4test
```

```bash
cd ~
sudo umount /mnt/ext4test
rm -rf /mnt/ext4test

rm ext4_test.img
```

Setup a target disk for tracing logs (XFS).

```bash
# make a 10GB empty image file
dd if=/dev/zero of=tracings.img bs=1M count=10240

# format it as XFS
mkfs.xfs tracings.img

# make a mount point
mkdir /mnt/tracings

# mount it using a loop device
sudo mount -o loop tracings.img /mnt/tracings
```

```bash
cd ~
sudo umount /mnt/tracings
rm -rf /mnt/tracings

rm tracings.img
```

## Kprobes

Run this command to find the Ext4 kernel probes.

```bash
cat /proc/kallsyms | awk '$2 ~ /^[Tt]$/ && $3 ~ /^ext4_/ { if(!seen[$3]++) print $3 }' > kprobes.txt
```

## Group

Create a group and replace the group id inside lttng script.

```bash
sudo groupadd ext4_grp
getent group ext4_grp
# ext4_grp:x:1002:

# test
sudo -g ext4_grp ls
```

## Challenges

1. LTTng ABI conflict with some of the tracepoints. Specifically, tracepoints that use complex data types which are not supported by LTTng.
    - Fixed by using kernel probes
    - Targeting 883 probes of Ext4 (only 10 failed to hook, 1.2% missing rate)
2. Running processes in different groups to minimize noise in the logs.
    - By using the group id, we can label and filter logs
3. Creating different workloads to trigger Ext4 features (e.g., journaling, failure recovery, etc.).
4. Mapping kernel stack addresses to functions or symbols.
5. Large volume of tracing results to parse (1 GB for only ext4 hit and 8 GB for callstack).
6. Tracer discarded 220,000 events when tracing with callstack option.
    - Even by enabling kstack tracing for only ext4 hit functions
7. Tracing results different even using the same test cases.
