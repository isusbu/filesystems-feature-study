#!/bin/bash

# ============================================================
# sqlite-bench Tracing — F2FS

# ============================================================


FSTYP=f2fs
MOUNT=/mnt/f2fs
GID=1002
GROUP=sqlite_trace
USER_NAME=sqlite_user
DB_DIR=$MOUNT/benchdb
SUFFIX="f2fs-sqlitebench"
OUTPUT="sqlitebench-f2fs"

echo "============================================"
echo " sqlite-bench Tracing — F2FS"
echo " Mount  : $MOUNT"
echo " DB Dir : $DB_DIR"
echo "============================================"

# ============================================================
# PART 1 — Check sqlite-bench
# ============================================================
echo ""
echo "--- Part 1: Checking sqlite-bench ---"
if ! command -v sqlite-bench &>/dev/null; then
    echo "ERROR: sqlite-bench not found."
    echo "Build it first:"
    echo "  cd ~/sqlite-bench"
    echo "  make"
    echo "  sudo mv sqlite-bench /usr/local/bin/"
    exit 1
fi
echo "sqlite-bench: $(which sqlite-bench)"


# ============================================================
# PART 2 — Initialize LTTng
# ============================================================
echo ""
echo "--- Part 2: Initializing LTTng session ---"

export FSTYP=$FSTYP
sudo -E ./lttng/init.sh $SUFFIX
echo "LTTng session initialized."

# ============================================================
# PART 3 — Drop Caches and Run Workload
# ============================================================
echo ""
echo "--- Part 3: Running workload ---"

# Drop caches (cold start)
echo "Dropping caches for cold start..."
sudo sync
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
echo "Caches dropped."

# Clean DB dir
echo "Cleaning DB directory..."
sudo rm -rf $DB_DIR && sudo mkdir -p $DB_DIR
sudo chown $USER_NAME:$GROUP $DB_DIR

# Start tracing
echo "Starting tracing..."
sudo -E ./lttng/start.sh $SUFFIX

# Run sqlite-bench workload
echo "Running sqlite-bench as $USER_NAME (GID $GID)..."
sudo -u $USER_NAME sqlite-bench \
    --benchmarks=fillseq,fillseqsync,fillseqbatch,fillrandom,fillrandsync,fillrandbatch,readseq,readrandom,readrand100K \
    --db=$DB_DIR \
    --num=1000000 \
    --value_size=100 \
    --WAL_enabled=1

# Disk usage
echo ""
echo "Disk usage after workload:"
df -h $MOUNT

# ============================================================
# PART 4 — Stop Tracing and Collect Results
# ============================================================
echo ""
echo "--- Part 4: Stopping tracing ---"
sudo -E ./lttng/stop.sh $SUFFIX $OUTPUT

# Coverage
COUNT_FILE="/mnt/gpfs/fs-study/f2fs-session-${SUFFIX}/${OUTPUT}.out.count"
if [ -f "$COUNT_FILE" ]; then
    TOTAL=$(wc -l < "$COUNT_FILE")
    HIT=$(awk -F: '$2 > 0' "$COUNT_FILE" | wc -l)
    PCT=$(echo "scale=1; $HIT * 100 / $TOTAL" | bc)
    echo ""
    echo "============================================"
    echo " F2FS Coverage: $HIT / $TOTAL ($PCT%)"
    echo " Results: $COUNT_FILE"
    echo "============================================"
fi

# ============================================================
# PART 5 — Cleanup LTTng
# ============================================================
echo ""
echo "--- Part 5: Cleaning up LTTng session ---"
./lttng/cleanup.sh $SUFFIX
echo "LTTng session cleaned up."
