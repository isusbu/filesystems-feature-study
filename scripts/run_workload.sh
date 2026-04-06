#!/bin/bash
# run_workload.sh

# Load metadata
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

USERNAME=$(whoami)
PROJECT_DIR="/home/${USERNAME}/filesystems-feature-study/"
XFSTESTS_PATH="/var/tmp/xfstests-dev-run"
LTTNG_DIR="/home/${USERNAME}/filesystems-feature-study/lttng"

#rm -f "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"
#touch "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"
#chmod 666 "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"

# keep sudo alive
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "---------------"
# Force the logs to be writable so 'init.sh' can record the hook status
sudo rm -f "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"
touch "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"
chmod 666 "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"
echo "-------------"
getent group ext4_grp
# DESTROY ghost sessions
sudo lttng destroy --all

sudo umount /mnt/${FS}Test # Unmount so we can format
sudo umount /mnt/${FS}Scratch

# Ensure the TEST_DEV matches the FS we want to trace
echo ">>> Ensuring /dev/loop10 amd 11 are formatted as $FS..."
sudo mkfs.${FS} -f /dev/loop10
sudo mkfs.${FS} -f /dev/loop11

# Init and Start LTTng Tracer
echo ">>> Starting Tracer for Session: $SESSION"
(cd "$PROJECT_DIR" && sudo ./lttng/init.sh "$SESSION" && sudo ./lttng/start.sh "$SESSION")

# Define the log name using the batch identifier
TIMESTAMP_LOG="${GPFS_BUCKET}/timestamps_${BATCH_NAME}.log"

# Workload Loop -  run tests (TODO : consider running 5-10 tests max at a time, as log could be enormous??)
for i in $(seq -f "%03g" $START $END); do
    TEST_NAME="${TEST_FOLDER}/${i}"
    [ ! -f "${XFSTESTS_PATH}/tests/${TEST_NAME}" ] && continue

    echo "${TEST_NAME},$(date +%H:%M:%S)" >> "${TIMESTAMP_LOG}"
    
    cd "$XFSTESTS_PATH"
    sudo -E sg ext4_grp -c "./check $TEST_NAME" | tee "$GPFS_BUCKET/testing_logs/${TEST_FOLDER}_${i}.out"
    
    echo "Sleeping for 15 seconds until next test"
    sleep 15
done

# Stop tracer & move big lttng log
echo ">>> Stopping Tracer..."
(cd "$PROJECT_DIR" && sudo ./lttng/stop.sh "$SESSION" && sudo ./lttng/cleanup.sh "$SESSION")

SOURCE_LOG="/mnt/gpfs/fs-study/${FS}-session-${SESSION}.out"
LOG_KPROBE_COUNT="/mnt/gpfs/fs-study/${FS}-session-${SESSION}.out.count"
TARGET_LOG="$GPFS_BUCKET/lttng_all_traces.out"
TARGET_LOG_KPROBE_COUNT="$GPFS_BUCKET/lttNg_all_traces.out.count"

if [ -f "$SOURCE_LOG" ]; then
    sudo mv "$SOURCE_LOG" "$TARGET_LOG"
    sudo mv "$LOG_KPROBE_COUNT" "$TARGET_LOG_KPROBE_COUNT"
    sudo cp "$LTTNG_DIR/failed.txt" "$GPFS_BUCKET/failed_global.txt"
    sudo cp "$LTTNG_DIR/hooked.txt" "$GPFS_BUCKET/hooked_global.txt"
    sudo chown $(whoami):$(id -gn) "$GPFS_BUCKET"
    echo "Workload complete. Giant lttng log saved to $TARGET_LOG"
else
   echo "!!! ERROR: Source log not found at $SOURCE_LOG"
fi

