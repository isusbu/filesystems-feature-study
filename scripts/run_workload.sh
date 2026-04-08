#!/bin/bash

# load metadata
if [ ! -f "/tmp/trace_metadata.env" ]; then
    echo "Error: Metadata file missing! Run set_env.sh first."
    exit 1
fi
source /tmp/trace_metadata.env

if [ -z "$FSTYP" ]; then
    echo "Error: FSTYP not found in metadata. Source likely failed or file is malformed."
    exit 1
fi
FS=${FSTYP}

USERNAME="${SUDO_USER:-$USER}"
PROJECT_DIR="/home/${USERNAME}/filesystems-feature-study/"
XFSTESTS_PATH="/var/tmp/xfstests-dev-run"
LTTNG_DIR="/home/${USERNAME}/filesystems-feature-study/lttng"

getent group ext4_grp

umount /mnt/${FS}Test # Unmount so we can format
umount /mnt/${FS}Scratch

echo ">>> Ensuring /dev/loop10 amd 11 are formatted as $FS..."
if [ "$FS" == "ext4" ]; then
    # ext4 uses -F (capital) to force formatting a partition
    mkfs.ext4 -F /dev/loop10
    mkfs.ext4 -F /dev/loop11
else
    # f2fs and xfs use -f (lowercase)
    mkfs.${FS} -f /dev/loop10
    mkfs.${FS} -f /dev/loop11
fi

# init and Start LTTng Tracer
echo ">>> Starting Tracer for Session: $SESSION"
(cd "$PROJECT_DIR" && ./lttng/init.sh "$SESSION")

# workload Loop - run tests (TODO : consider running 5-10 tests max at a time, as log could be enormous??)
for i in $(seq -f "%03g" $START $END); do
    TEST_NAME="${TEST_FOLDER}/${i}"
    [ ! -f "${XFSTESTS_PATH}/tests/${TEST_NAME}" ] && continue

    ./lttng/start.sh "$SESSION"
    
    (cd "$XFSTESTS_PATH" && sudo -E sg ext4_grp -c "./check $TEST_NAME" | tee "$XFS_TESTS_LOGS_DIRECTORY/${TEST_FOLDER}_${i}.out")
    
    (cd "$PROJECT_DIR" && ./lttng/stop.sh "$SESSION" "xfstests_${TEST_FOLDER}_${i}")
done

# Stop tracer & move big lttng log
echo ">>> Stopping Tracer..."
(cd "$PROJECT_DIR" &&./lttng/cleanup.sh "$SESSION")

SOURCE_LOG="${GPFS_BUCKET}/${FS}-session-${SESSION}.out"
LOG_KPROBE_COUNT="${GPFS_BUCKET}/${FS}-session-${SESSION}.out.count"
TARGET_LOG="$OUTPUT_DIR/lttng_all_traces.out"
TARGET_LOG_KPROBE_COUNT="$OUTPUT_DIR/lttng_all_traces.out.count"

if [ -f "$SOURCE_LOG" ]; then
    sudo mv "$SOURCE_LOG" "$TARGET_LOG"
    sudo mv "$LOG_KPROBE_COUNT" "$TARGET_LOG_KPROBE_COUNT"
    sudo cp "$LTTNG_DIR/failed.txt" "$OUTPUT_DIR/failed_global.txt"
    sudo cp "$LTTNG_DIR/hooked.txt" "$OUTPUT_DIR/hooked_global.txt"
    sudo chown $(whoami):$(id -gn) "$OUTPUT_DIR"
    echo "Workload complete. Giant lttng log saved to $TARGET_LOG"
else
   echo "!!! ERROR: Source log not found at $SOURCE_LOG"
fi
