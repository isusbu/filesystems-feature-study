#!/bin/bash

# input about configurations and tests
while true; do
    read -p "Enter Filesystem (ext4, nfs, f2fs, btrfs): " FSTYP
    FSTYP=$(echo "$FSTYP" | tr '[:upper:]' '[:lower:]')
    [[ "$FSTYP" =~ ^(ext4|nfs|f2fs|btrfs)$ ]] && break || echo "Invalid FS."
done

# xfs requirements
read -p "Enter Test Folder [default: $FSTYP]: " TEST_FOLDER
TEST_FOLDER=${TEST_FOLDER:-$FSTYP}

read -p "Start Test #: " START
read -p "End Test #: " END

# path setup
DATE_AND_TIME="$(date +%Y%m%d_%H%M)"
USERNAME="${SUDO_USER:-$USER}"
BATCH_NAME="xfstests_${FSTYP}_${TEST_FOLDER}_${START}_to_${END}_${DATE_AND_TIME}"
GPFS_BUCKET="/mnt/gpfs/fs-study"

LOG_DIRECTORY="${GPFS_BUCKET}/${USERNAME}/${FSTYP}/${TEST_FOLDER}/${BATCH_NAME}"
mkdir -p ${LOG_DIRECTORY}

XFS_TESTS_LOGS_DIRECTORY="${LOG_DIRECTORY}/xfstests_logs"
mkdir -p ${XFS_TESTS_LOGS_DIRECTORY}

# create local.config in xfstests path
XFSTESTS_PATH="/var/tmp/xfstests-dev-run"
if [ "$FSTYP" == "nfs" ]; then
    cat <<EOF > "${XFSTESTS_PATH}/local.config"
export FSTYP=nfs
export TEST_DEV=127.0.0.1:/srv/nfstest
export TEST_DIR=/mnt/nfstest
export SCRATCH_DEV=127.0.0.1:/srv/nfsscratch
export SCRATCH_MNT=/mnt/nfsscratch
export NFS_MOUNT_OPTIONS="-o rw,relatime,vers=4.2"
export MOUNT_OPTIONS="-o rw,relatime,vers=4.2"
EOF
else
    # Back TEST/SCRATCH with our own image files on local disk and attach them to FREE loop devices.
    # (Hard-coded /dev/loop10/11 can belong to snapd on this VM; formatting them would damage snaps.)
    IMG_DIR=${IMG_DIR:-/srv/xfstests_imgs}
    IMG_SIZE=${IMG_SIZE:-6G}
    mkdir -p "$IMG_DIR" /mnt/${FSTYP}Test /mnt/${FSTYP}Scratch
    for role in test scratch; do
        img="$IMG_DIR/${FSTYP}_${role}.img"
        [ -f "$img" ] || truncate -s "$IMG_SIZE" "$img"          # sparse: uses disk only as written
        dev=$(losetup -j "$img" | cut -d: -f1 | head -1)          # reuse if already attached
        [ -n "$dev" ] || dev=$(losetup -f --show "$img")
        [ -n "$dev" ] || { echo "ERROR: could not attach $img to a loop device"; exit 1; }
        if [ "$role" = test ]; then TEST_LOOP=$dev; else SCRATCH_LOOP=$dev; fi
    done
    echo "TEST_DEV=$TEST_LOOP  SCRATCH_DEV=$SCRATCH_LOOP  (images in $IMG_DIR)"

    # Multi-device tests (btrfs RAID, device add/remove/replace, balance) need SCRATCH_DEV_POOL.
    # xfstests uses the FIRST pool device as SCRATCH_DEV and requires SCRATCH_DEV itself to be unset.
    # POOL_EXTRA extra images are added after the scratch image (default 4 for btrfs -> pool of 5; 0 = no pool).
    if [ "$FSTYP" == "btrfs" ]; then POOL_EXTRA=${POOL_EXTRA:-4}; else POOL_EXTRA=${POOL_EXTRA:-0}; fi
    POOL="$SCRATCH_LOOP"
    for i in $(seq 1 "$POOL_EXTRA"); do
        img="$IMG_DIR/${FSTYP}_pool${i}.img"
        [ -f "$img" ] || truncate -s "$IMG_SIZE" "$img"
        dev=$(losetup -j "$img" | cut -d: -f1 | head -1)
        [ -n "$dev" ] || dev=$(losetup -f --show "$img")
        [ -n "$dev" ] || { echo "ERROR: could not attach $img"; exit 1; }
        POOL="$POOL $dev"
    done

    {
        echo "export TEST_DEV=$TEST_LOOP"
        echo "export TEST_DIR=/mnt/${FSTYP}Test"
        if [ "$POOL_EXTRA" -gt 0 ]; then
            echo "export SCRATCH_DEV_POOL=\"$POOL\""
            echo "SCRATCH_DEV_POOL=$POOL" >&2
        else
            echo "export SCRATCH_DEV=$SCRATCH_LOOP"
        fi
        echo "export SCRATCH_MNT=/mnt/${FSTYP}Scratch"
        echo "export FSTYP=$FSTYP"
    } > "${XFSTESTS_PATH}/local.config"
    echo "free disk for images: $(df -h --output=avail "$IMG_DIR" | tail -1) (images are sparse; heavy tests fill them)"
fi

rm -f /tmp/trace_metadata.env

# save metadata for script 2 
cat <<EOF > /tmp/trace_metadata.env
FSTYP=$FSTYP
TEST_FOLDER=$TEST_FOLDER
START=$START
END=$END
BATCH_NAME=$BATCH_NAME
GPFS_BUCKET=$GPFS_BUCKET
OUTPUT_DIR=$LOG_DIRECTORY
SESSION="fs_${FSTYP}_tests_${TEST_FOLDER}_${START}_${END}_${DATE_AND_TIME}"
XFS_TESTS_LOGS_DIRECTORY=${XFS_TESTS_LOGS_DIRECTORY}
TEST_LOOP=${TEST_LOOP:-}
SCRATCH_LOOP=${SCRATCH_LOOP:-}
EOF

echo "Setup Complete. Metadata saved to /tmp/trace_metadata.env"
