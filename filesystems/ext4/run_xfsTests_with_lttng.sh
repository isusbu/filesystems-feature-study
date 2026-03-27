#!/bin/bash


# -- USER INPUT ---
echo " Enter Filesystem (ext4 or xfs):"
read FSTYP

echo "Enter Start Test Number (e.g., 1):"
read START
echo "Enter End Test Number (e.g., 50):"
read END

# folder for logs  on GPFS
DATE_AND_TIME="$(date +%Y%m%d_%H%M)"
BATCH_NAME="satche_xfsTests_lttng_traces_${FSTYP}_${START}_to_${END}_$DATE_AND_TIME"
GPFS_BUCKET="/mnt/gpfs/fs-study/$BATCH_NAME"
mkdir -p "$GPFS_BUCKET"

echo "All logs for this batch will be saved to: $GPFS_BUCKET"

# Paths
XFSTESTS_PATH="/var/tmp/xfstests-dev-run"
LTTNG_DIR="/home/satche/filesystems-feature-study/lttng"
RESULTS_DIR="/var/tmp/xfsTests_testing_${FSTYP}_${START}_to_${END}_${DATE_AND_TIME}"

echo "XFSTESTS_PATH : ${XFSTESTS_PATH}"
echo "LTTNG_DIR : ${LTTNG_DIR}"
echo "RESULTS_DIR : ${RESULTS_DIR}"

mkdir -p "$RESULTS_DIR"

# --- SAFETY CHECK ---
# Check if we have at least 1GB left to avoid system crash
FREE_SPACE=$(df /var/tmp | awk 'NR==2 {print $4}')
if [ "$FREE_SPACE" -lt 1048576 ]; then
    echo "FATAL ERROR: Disk space too low ($((FREE_SPACE/1024))MB). Stopping to save system."
    exit 1
fi

getent group ext4_grp

# --- THE TEST LOOP ---
# This uses the range you provided and ignores missing tests
for i in $(seq -f "%03g" $START $END); do
    TEST_NAME="${FSTYP}/${i}"
    TEST_FILE="${XFSTESTS_PATH}/tests/${TEST_NAME}"

    # Verify if the test file exists on disk
    if [ ! -f "$TEST_FILE" ]; then
        echo "Skipping $TEST_NAME: File not found."
        continue
    fi

    echo ">>> STARTING: $TEST_NAME"

    # Define unique session for LTTng
    SESSION="study_${FSTYP}_${i}"

   echo ">>> initialising session and probes"
   
    sudo rm -f "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"
    sudo touch "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"
    sudo chmod 666 "$LTTNG_DIR/hooked.txt" "$LTTNG_DIR/failed.txt"
    (cd "$LTTNG_DIR" && sudo ./init.sh "$SESSION")

    #  A: Start
    echo "    Starting Tracer..."
    (cd "$LTTNG_DIR" && sudo ./start.sh "$SESSION")

    # B: Run Workload
    # This relies on YOUR manually set local.config in the xfstests folder
    cd "$XFSTESTS_PATH"
    pwd
    ls
    echo "test : $TEST_NAME"
    sudo -E sg ext4_grp  "./check $TEST_NAME" | tee "${RESULTS_DIR}/${FSTYP}_${i}.out"

    # C: Stop LTTng
    (cd "$LTTNG_DIR" && sudo ./stop.sh "$SESSION" && sudo ./cleanup.sh "$SESSION")
 
    # D: Move the file to your specific batch folder
    SOURCE_LOG="/mnt/gpfs/fs-study/ext4-session-${SESSION}.out"
    if [ -f "$SOURCE_LOG" ]; then
        mv "$SOURCE_LOG" "${GPFS_BUCKET}/"
        cp "${LTTNG_DIR}/failed.txt" "${GPFS_BUCKET}/failed_${i}.txt"
        cp "${LTTNG_DIR}/hooked.txt" "${GPFS_BUCKET}/hooked_${i}.txt"
        echo "      Logs moved to $GPFS_BUCKET"
    else
        echo "      ERROR: Could not find log at $SOURCE_LOG"
    fi    
    
    echo "Done with $TEST_NAME. sleep for 45s ..."
    #sleep for 45 seconds to recover
    sleep 45
done

echo "Batch testing done"
echo "Batch finished. XfsTests Logs are in $RESULTS_DIR and trace logs in $GPFS_BUCKET"
