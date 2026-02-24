# FSL Research Document: XFS Tests for Tracing

Researcher: Sravya Atche

Environment: Stony Brook FSL Lab (VM: dhcp159)

Kernel: Linux 6.8.0

Project: XFS Feature Analysis via LTTng & Kprobes

# Phase 1: Environment Preparation

To ensure high-performance I/O and isolate the filesystem, we utilize local loopback devices.

# Create 2GB disk images for feature testing

# make a 2GB empty image file
dd if=/dev/zero of=xfs_test.img bs=1M count=2048

# format it 
mkfs.ext4 ext4_test.img
or 
mkfs.xfs xfs_test.img

# make a mount point
mkdir /mnt/xfstest

# mount it using a loop device
sudo mount -o loop xfs_test.img /mnt/xfstest

or 

sudo losetup -fP xfs_test.img

Make sure the loop device is in writable location, not on NFS mounted directory, clearup disabled  and is RW. Because xfs expects a root to be able to write to these disks for performing tests

We utilize a dual-loopback architecture to comply with `xfstests` requirements for independent `TEST` and `SCRATCH` areas.
Loopback Device 1(xfs_test): Dedicated to the persistent test environment.
Loopback Device 2(xfs_scratch): Dedicated to destructive feature testing.

Benefit: This isolation ensures that a failure in an XFS feature on the `SCRATCH` device does not crash the entire test runner sitting on the `TEST` device.

# Phase 2 System Configuration for XFS tests

We need to configure the local.config so that xfs-tests use our loopback devices instead of actual system disk

File Path : xfstests-dev/local-config

TEST_DEV=/dev/loop8: Points to our persistent environment.

SCRATCH_DEV=/dev/loop9: Points to our destructive test area.

TEST_DIR=/mnt/xfstest: The mount point for the persistent disk.

SCRATCH_MNT=/mnt/xfsscratch: The mount point for the volatile disk.

(FSTYP=xfs: Explicitly tells the suite to use the XFS driver features.)

# Phase 3: Reading kernel interfaces for this file system (kprobes)

Search for all available XFS functions the kernel knows (t is for functions)
grep "xfs_" /proc/kallsyms | grep "t "

grep "\[xfs\]" /proc/kallsyms | grep " t " | awk '{print $3}' > available_xfs_probes.txt

Write them to kprobes.txt

# Phase 4: LTTng Monitoring

Mechanism: Dynamic Kprobes for zero-source-code modification.

Buffering: Lock-less, Per-CPU Ring Buffers to minimize "Observer Effect" (overhead).

Output Format: CTF (Common Trace Format) for high-efficiency binary storage.

Contextual Metadata: Every event is tagged with hostname, cpu_id, and tid (thread ID).

1. Initialisation script - sudo ./init.sh xfs_tests_0
Status: Complete. (2,316 probes successfully hooked).

Permission issues for hooked and failed : Create them as 'satche' (the owner of the directory)
touch hooked.txt failed.txt

Make them world-writable so the sudo script can write into them
chmod 666 hooked.txt failed.txt

Now run the script—it will succeed because the files already exist
sudo ./init.sh

2. Activation - sudo ./start.sh xfs_tests_0
this allows kernel to start writing function call data to ring buffers

# Phase 4: Workload Execution and Data Collevtion

Now, we run the actual test. Since we are using the dual-loopback setup, we need to make sure our loop devices are attached before running the command.

sudo losetup

if we want to attach, use

sudo losetup /dev/loop8 /var/tmp/xfs_test.img
sudo losetup /dev/loop9 /var/tmp/xfs_scratch.img

We run the tests under a specific group id, so that we can only monitor calls made by test suite and ignore all background noise. So, We tell LTTng to Only record events if the process belongs to GID 1002

cd xfstests-dev
sudo sg ext4_grp -c "sudo ./check xfs/001"

Repeat this for multiple tests

# Phase 5: Post-Processing & Analysis

Once the test finishes, we stop the recording and convert the binary data into a format you can use for your report

cd ../lttng
sudo ./stop.sh xfs_tests_0
sudo ./cleanup.sh xfs_tests_0

We can see binary data in /mnt/gpfs/fs-study/ext4-session-xfs_tests_0, and we get .out file of the same which is in readable format after running cleanup.sh

# This saves the list of unique functions that were ACTUALLY used to a file
babeltrace2 /mnt/gpfs/fs-study/ext4-session-xfs_tests_0 | awk '{print $4}' | sort -u > utilized_functions.txt

# This gives you the final count for your report
wc -l utilized_functions.txt

# This shows the function name and how many times it was called, sorted by most used
babeltrace2 /mnt/gpfs/fs-study/ext4-session-xfs_tests_0 | awk '{print $4}' | sort | uniq -c | sort -nr > function_frequency.txt


# For ext4 testing

## Important: NFS / sudo write limitation

If you run `xfstests` from an NFS-backed path (example: `/home/satche/...`) using `sudo`, writes may fail because of NFS root-squash behavior.

Typical errors:
- `Permission denied` creating `results/...`
- `ln: failed to create symbolic link ... tests/ext4/001.out`

This can also cause misleading follow-up messages like:
- `this test requires a valid $TEST_DEV`

### Quick check

sudo touch /home/satche/filesystems-feature-study/lttng/xfstests-dev/.root_write_test
sudo touch /var/tmp/.root_write_test

if the first one fails and second passes it confirms the issue.

That caused misleading “invalid $TEST_DEV” / setup failures even though loop devices were valid when running the ext4 tests

Fix: 

Moved runtime to local disk: /var/tmp/xfstests-dev-run (writable for root processes).
Kept destructive workload isolated to loop devices only.
Ensured xfstests had writable paths for both output and per-test expected-output links.
Outcome : xfstests now runs correctly on ext4 from /var/tmp/xfstests-dev-run, and this setup is suitable to wrap with LTTng init/start/stop/cleanup for trace collection.

Recommended xfstests run location
rsync -a /home/satche/filesystems-feature-study/lttng/xfstests-dev/ /var/tmp/xfstests-dev-run/
cd /var/tmp/xfstests-dev-run
./configure
make -j"$(nproc)"

/home/satche/filesystems-feature-study/lttng/xfstests-dev is NFS-backed.
With sudo, root is squashed there, so test setup writes fail (001.out symlink, results files).

Use this as stable command :
sudo sg ext4_grp -c 'cd /var/tmp/xfstests-dev-run && ./check ext4/001'

