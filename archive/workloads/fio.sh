#!/bin/bash

echo "=== FIO EXT4 Feature Testing Suite ==="
echo ""

# Create test directory
TEST_DIR="fio_ext4_test"
mkdir -p "$TEST_DIR"

echo "Test directory: $(pwd)"
echo ""

selected_test="$1"

# -------------------------------
# Function: run one FIO test
# -------------------------------
run_fio_test() {
    local num="$1"
    local name="$2"
    local config="$3"
    local features="$4"

    echo "=============================================="
    echo " TEST $num: $name"
    echo "=============================================="
    echo "Expected EXT4 features: $features"
    echo ""

    cd "$TEST_DIR" || exit 1

    echo "$config" > "${name}.fio"
    echo "Running: fio ${name}.fio"
    fio "${name}.fio"

    echo "Completed test: $name"
    echo "----------------------------------------------"
    echo ""

    cd .. || exit 1
}

# -------------------------------
# Wrapper to filter tests
# -------------------------------
run_test() {
    local num="$1"
    local desc="$2"
    shift 2

    if [[ -z "$selected_test" || "$selected_test" == "$num" ]]; then
        echo "$num. $desc"
        run_fio_test "$num" "$@"
    fi
}

# -------------------------------
# TEST DEFINITIONS
# -------------------------------
run_test 1 "SEQUENTIAL WRITE TEST (Basic extent allocation)" \
"seq_write" "[seq_write]
rw=write
size=100M
bs=4k
direct=1
filename=seq_test_file
name=sequential_write" \
"write, extent, bigalloc, has_journal"

run_test 2 "RANDOM WRITE TEST (Extent fragmentation)" \
"rand_write" "[rand_write]
rw=randwrite
size=100M
bs=4k
direct=1
filename=rand_test_file
name=random_write" \
"write, extent, bigalloc, has_journal"

run_test 3 "FSYNC HEAVY TEST (Journal operations)" \
"fsync_heavy" "[fsync_heavy]
rw=write
size=50M
bs=4k
direct=0
fsync=1
filename=fsync_test_file
name=fsync_heavy" \
"write, fsync, has_journal, extent"

run_test 4 "FALLOCATE TEST (Pre-allocation)" \
"fallocate_test" "[fallocate_test]
rw=write
size=200M
bs=64k
fallocate=native
filename=falloc_test_file
name=fallocate_test" \
"fallocate, extent, huge_file, bigalloc"

run_test 5 "LARGE FILE TEST (Huge file support)" \
"large_file" "[large_file]
rw=write
size=1G
bs=1M
direct=1
filename=large_test_file
name=large_file" \
"write, extent, huge_file, large_file, bigalloc"

run_test 6 "MIXED I/O TEST (Various patterns)" \
"mixed_io" "[mixed_io]
rw=randrw
rwmixread=70
size=100M
bs=4k
direct=1
filename=mixed_test_file
name=mixed_io" \
"write, extent, bigalloc, has_journal"

run_test 7 "SMALL FILES TEST (Directory operations, filetype)" \
"small_files" "[small_files]
rw=write
size=1M
bs=4k
nrfiles=100
filesize=10k
filename_format=small_file.\$jobnum.\$filenum
name=small_files" \
"create, write, filetype, dir_nlink, ext_attr"

run_test 8 "SYNC INTENSIVE TEST (Heavy journal activity)" \
"sync_intensive" "[sync_intensive]
rw=write
size=50M
bs=4k
direct=0
sync=1
filename=sync_test_file
name=sync_intensive" \
"write, fsync, has_journal, extent"

run_test 9 "TRUNCATE/EXTEND TEST (File size operations)" \
"truncate_test" "[truncate_test]
rw=write
size=100M
bs=4k
file_append=1
filename=truncate_test_file
name=truncate_test" \
"write, extent, large_file, has_journal"

run_test 10 "ZERO WRITE TEST (Unwritten extents)" \
"zero_write" "[zero_write]
rw=write
size=100M
bs=64k
zero_buffers=1
filename=zero_test_file
name=zero_write" \
"write, extent, bigalloc, has_journal"

# -------------------------------
# Final summary
# -------------------------------
if [[ -z "$selected_test" ]]; then
    echo ""
    echo "=== All 10 FIO tests complete ==="
    echo ""
else
    echo ""
    echo "=== Test $selected_test complete ==="
    echo ""
fi
