#!/bin/bash
# set_env.sh

# Input about configurations and tests
while true; do
    read -p "Enter Filesystem (ext4, xfs, f2fs): " FSTYP
    FSTYP=$(echo "$FSTYP" | tr '[:upper:]' '[:lower:]')
    [[ "$FSTYP" =~ ^(ext4|xfs|f2fs)$ ]] && break || echo "Invalid FS."
done

read -p "Enter Test Folder [default: $FSTYP]: " TEST_FOLDER
TEST_FOLDER=${TEST_FOLDER:-$FSTYP}

read -p "Start Test #: " START
read -p "End Test #: " END

# Path Setup
DATE_AND_TIME="$(date +%Y%m%d_%H%M)"
BATCH_NAME="xfsTests_${FSTYP}_${TEST_FOLDER}_${START}_to_${END}_${DATE_AND_TIME}"
GPFS_BUCKET="/mnt/gpfs/fs-study/sravya/$BATCH_NAME"
mkdir -p "$GPFS_BUCKET/testing_logs"

# Create local.config in xfstests path
XFSTESTS_PATH="/var/tmp/xfstests-dev-run"
cat <<EOF > "${XFSTESTS_PATH}/local.config"
export TEST_DEV=/dev/loop10
export TEST_DIR=/mnt/${FSTYP}Test
export SCRATCH_DEV=/dev/loop11
export SCRATCH_MNT=/mnt/${FSTYP}Scratch
export FSTYP=$FSTYP
EOF

# Save Metadata for Script 2 and 3
cat <<EOF > /tmp/trace_metadata.env
FSTYP=$FSTYP
TEST_FOLDER=$TEST_FOLDER
START=$START
END=$END
BATCH_NAME=$BATCH_NAME
GPFS_BUCKET=$GPFS_BUCKET
SESSION="session_${DATE_AND_TIME}"
EOF

echo "Setup Complete. Metadata saved to /tmp/trace_metadata.env"

