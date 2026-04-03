#!/bin/bash
# run_workload.sh

# Load metadata
source /tmp/trace_metadata.env

LTTNG_DIR="/home/satche/filesystems-feature-study/lttng"
XFSTESTS_PATH="/var/tmp/xfstests-dev-run"

# keep sudo alive
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Init and Start LTTng Tracer
echo ">>> Starting Tracer for Session: $SESSION"
(cd "$LTTNG_DIR" && sudo ./init.sh "$SESSION" && sudo ./start.sh "$SESSION")

# Define the log name using the batch identifier
TIMESTAMP_LOG="${GPFS_BUCKET}/timestamps_${BATCH_NAME}.log"

# Workload Loop -  run tests (TODO : consider running 5-10 tests max at a time, as log could be enormous??)
for i in $(seq -f "%03g" $START $END); do
    TEST_NAME="${TEST_FOLDER}/${i}"
    [ ! -f "${XFSTESTS_PATH}/tests/${TEST_NAME}" ] && continue

    echo "${TEST_NAME},$(date +%H:%M:%S)" >> "${TIMESTAMP_LOG}"
    
    cd "$XFSTESTS_PATH"
    sudo -E sg ext4_grp -c "./check $TEST_NAME" | tee "$GPFS_BUCKET/testing_logs/${TEST_FOLDER}_${i}.out"
    
    sleep 30
done

# Stop tracer & move big lttng log
echo ">>> Stopping Tracer..."
(cd "$LTTNG_DIR" && sudo ./stop.sh "$SESSION" && sudo ./cleanup.sh "$SESSION")

SOURCE_LOG="/mnt/gpfs/fs-study/ext4-session-${SESSION}.out"
TARGET_LOG="$GPFS_BUCKET/lttng_all_traces.out"
if [ -f "$SOURCE_LOG" ]; then
    sudo mv "$SOURCE_LOG" "$TARGET_LOG"
    sudo cp "$LTTNG_DIR/failed.txt" "$GPFS_BUCKET/failed_global.txt"
    sudo cp "$LTTNG_DIR/hooked.txt" "$GPFS_BUCKET/hooked_global.txt"
    sudo chown $(whoami):$(id -gn) "$GPFS_BUCKET"
    echo "Workload complete. Giant lttng log saved to $TARGET_LOG"
else
   echo "!!! ERROR: Source log not found at $SOURCE_LOG"
fi

