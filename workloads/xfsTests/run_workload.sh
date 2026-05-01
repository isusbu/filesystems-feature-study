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

echo ">>> Preparing $FS environment..."
# Initialize an empty variable for extra flags
EXTRA_FLAGS=""

if [ "$FS" == "nfs" ]; then
    EXTRA_FLAGS="-nfs"
    # Force unmount client side to prevent "Stale File Handle"
    sudo umount -l /mnt/nfstest
    sudo umount -l /mnt/nfsscratch
    
    # "Formatting" NFS = Cleaning the server-side directories
    sudo rm -rf /srv/nfstest/*
    sudo rm -rf /srv/nfsscratch/*
    
    # Refresh the server
    sudo exportfs -ra
    sudo systemctl restart nfs-kernel-server
else
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
fi

LTTNG_OUTPUT_DIR="${OUTPUT_DIR}/lttng_logs"
mkdir ${LTTNG_OUTPUT_DIR}

# init and Start LTTng Tracer
echo ">>> Starting Tracer for Session: $SESSION"
(cd "$PROJECT_DIR" && ./lttng/init.sh "$SESSION")

# workload Loop - run tests (TODO : consider running 5-10 tests max at a time, as log could be enormous??)
for i in $(seq -f "%03g" $START $END); do
    TEST_NAME="${TEST_FOLDER}/${i}"
    [ ! -f "${XFSTESTS_PATH}/tests/${TEST_NAME}" ] && continue

    (cd "$PROJECT_DIR" && ./lttng/start.sh "$SESSION")
    
    (cd "$XFSTESTS_PATH" && sudo -E sg ext4_grp -c "./check $EXTRA_FLAGS $TEST_NAME" | tee "$XFS_TESTS_LOGS_DIRECTORY/${TEST_FOLDER}_${i}.out")
    
    (cd "$PROJECT_DIR" && ./lttng/stop.sh "$SESSION" "xfstests_${TEST_FOLDER}_${i}")

    ACTUAL_SOURCE_DIR="${GPFS_BUCKET}/${FS}-session-${SESSION}"

    if [ -d "$ACTUAL_SOURCE_DIR" ]; then
       echo ">>> Moving all logs from $ACTUAL_SOURCE_DIR to $LTTNG_OUTPUT_DIR"
    
       # Move all individual test logs and count files to your batch output folder
       sudo mv "$ACTUAL_SOURCE_DIR"/* "$LTTNG_OUTPUT_DIR/"
    
       # Also copy the global hook lists
       sudo cp "$LTTNG_DIR/failed.txt" "$OUTPUT_DIR/failed_global.txt"
       sudo cp "$LTTNG_DIR/hooked.txt" "$OUTPUT_DIR/hooked_global.txt"
    
       # Clean up the temporary session directory
       sudo rm -rf "$ACTUAL_SOURCE_DIR"
    
       sudo chown -R $(whoami):$(id -gn) "$OUTPUT_DIR"
       echo "Workload complete. All traces saved to $OUTPUT_DIR"
    else
       echo "!!! ERROR: Source directory not found at $ACTUAL_SOURCE_DIR"
    fi
    sleep 5

done

# Stop tracer & move big lttng log
echo ">>> Stopping Tracer..."
(cd "$PROJECT_DIR" &&./lttng/cleanup.sh "$SESSION")

sudo lttng destroy --all

if [ "$FS" == "nfs" ]; then
    echo ">>> Cleanup of NFS environment..."
    cd ~
    sudo umount -l /mnt/nfstest
    sudo rm -rf /mnt/nfstest/*

    sudo umount -l /mnt/nfsscratch
    sudo rm -rf /mnt/nfsscratch/*

    # server cleanup
#    sudo rm -f /etc/exports.d/nfstest.exports
 #   sudo rm -f /etc/exports.d/nfsscratch.exports
  #  sudo exportfs -ra
  #  sudo systemctl restart nfs-kernel-server

   # sudo rm -rf /srv/nfstest
   # sudo rm -rf /srv/nfsscratch

fi

echo "all done!"
