#!/bin/bash

# --- CONFIG ---------------------------------------------------------

LTTNG_SCRIPT="./lttng.sh"   # lttng runner (must accept a number argument)

# -------------------------------------------------------------------

echo "=== FIO EXT4 Feature Testing Suite ==="
echo ""

# Create test directory
TEST_DIR="fio_ext4_test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1

echo "Test directory: $(pwd)"
echo ""

# Function to run a single test with LTTNG start/stop
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

    #
    # 1 — Initialize LTTNG for this test
    #
    echo "[LTTNG] Initializing trace session: $num"
    $LTTNG_SCRIPT "$num"
    if [ $? -ne 0 ]; then
        echo "ERROR: lttng.sh failed for test $num"
        exit 1
    fi

    echo "[LTTNG] Starting trace"
    sudo lttng start --session="ext4-session"

    #
    # 2 — Write the FIO config and run workload
    #
    echo "$config" > "${name}.fio"
    echo "Running: fio ${name}.fio"
    fio "${name}.fio"

    #
    # 3 — Stop & Destroy LTTNG Session
    #
    echo "[LTTNG] Stopping trace"
    sudo lttng stop --session="ext4-session"

    echo "[LTTNG] Destroying session"
    sudo lttng destroy --session="ext4-session"

    echo "Completed test: $name"
    echo "----------------------------------------------"
    echo ""
}

# -------------------------
#  LIST OF 10 TEST CASES
# -------------------------
echo "1. SEQUENTIAL WRITE TEST (Basic extent allocation)"
run_fio_test 1 "seq_write" "[seq_write]
rw=write
size=100M
bs=4k
direct=1
filename=seq_test_file
name=sequential_write" \
"write, extent, bigalloc, has_journal"

echo "2. RANDOM WRITE TEST (Extent fragmentation)"
run_fio_test 2 "rand_write" "[rand_write]
rw=randwrite
size=100M
bs=4k
direct=1
filename=rand_test_file
name=random_write" \
"write, extent, bigalloc, has_journal"

echo "3. FSYNC HEAVY TEST (Journal operations)"
run_fio_test 3 "fsync_heavy" "[fsync_heavy]
rw=write
size=50M
bs=4k
direct=0
fsync=1
filename=fsync_test_file
name=fsync_heavy" \
"write, fsync, has_journal, extent"

echo "4. FALLOCATE TEST (Pre-allocation)"
run_fio_test 4 "fallocate_test" "[fallocate_test]
rw=write
size=200M
bs=64k
fallocate=native
filename=falloc_test_file
name=fallocate_test" \
"fallocate, extent, huge_file, bigalloc"

echo "5. LARGE FILE TEST (Huge file support)"
run_fio_test 5 "large_file" "[large_file]
rw=write
size=1G
bs=1M
direct=1
filename=large_test_file
name=large_file" \
"write, extent, huge_file, large_file, bigalloc"

echo "6. MIXED I/O TEST (Various patterns)"
run_fio_test 6 "mixed_io" "[mixed_io]
rw=randrw
rwmixread=70
size=100M
bs=4k
direct=1
filename=mixed_test_file
name=mixed_io" \
"write, extent, bigalloc, has_journal"

echo "7. SMALL FILES TEST (Directory operations, filetype)"
run_fio_test 7 "small_files" "[small_files]
rw=write
size=1M
bs=4k
nrfiles=100
filesize=10k
filename_format=small_file.\$jobnum.\$filenum
name=small_files" \
"create, write, filetype, dir_nlink, ext_attr"

echo "8. SYNC INTENSIVE TEST (Heavy journal activity)"
run_fio_test 8 "sync_intensive" "[sync_intensive]
rw=write
size=50M
bs=4k
direct=0
sync=1
filename=sync_test_file
name=sync_intensive" \
"write, fsync, has_journal, extent"

echo "9. TRUNCATE/EXTEND TEST (File size operations)"
run_fio_test 9 "truncate_test" "[truncate_test]
rw=write
size=100M
bs=4k
file_append=1
filename=truncate_test_file
name=truncate_test" \
"write, extent, large_file, has_journal"

echo "10. ZERO WRITE TEST (Unwritten extents)"
run_fio_test 10 "zero_write" "[zero_write]
rw=write
size=100M
bs=64k
zero_buffers=1
filename=zero_test_file
name=zero_write" \
"write, extent, bigalloc, has_journal"


echo ""
echo "=== All 10 FIO tests complete ==="
echo ""
