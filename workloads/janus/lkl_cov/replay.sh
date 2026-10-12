#!/bin/bash
# Replay inputs through the coverage build and record which btrfs functions each one runs.
#   baseline : the 9 seed programs (open/list files) on the UNMODIFIED seed image = "normal workload"
#   janus    : every input Janus saved in its queue (mutated image + mutated syscalls)
# Run INSIDE the container after build_cov.sh.
# Usage: bash replay.sh [queue_dir]
set -u
J=/usr/src/janus
W=${W:-/tmp/jc}
S=$(dirname "$(readlink -f "$0")")
Q=${1:-/mnt/janus_run_save/output/btrfs/queue}
R=$S/results
EXE=${EXE:-$W/lkl/tools/lkl/executor}
mkdir -p "$W"
SEED=$J/samples/evaluation/btrfs-00.image

[ -x "$EXE" ] || { echo "missing $EXE - run build_cov.sh first"; exit 1; }
[ -d "$Q" ]   || { echo "queue dir not found: $Q"; exit 1; }
mkdir -p "$R/baseline" "$R/janus"
rm -f "$R"/baseline/*.txt "$R"/janus/*.txt
cd "$J"

echo "== baseline: seed programs on the unmodified image =="
for p in prog/*; do
  name=$(basename "$p")
  cp "$SEED" "$W/seed.img"
  COV_OUT="$R/baseline/$name.txt" timeout 30 "$EXE" -t btrfs -i "$W/seed.img" -p "$p" >/dev/null 2>&1
  rc=$?
  echo "  $name exit=$rc funcs=$(cat "$R/baseline/$name.txt" 2>/dev/null | wc -l)"
done
rm -f "$W/seed.img"

echo "== janus queue: $(ls "$Q" | grep -c '^id:') inputs =="
for f in "$Q"/id:*; do
  id=$(basename "$f" | cut -d, -f1)
  if ! ./utils/afl-parse -i "$SEED" -t btrfs -f "$f" -o "$W/rep" >/dev/null 2>&1; then
    echo "  $id  (could not decode, skipped)"; continue
  fi
  COV_OUT="$R/janus/$id.txt" timeout 30 "$EXE" -t btrfs -i "$W/rep.img" -p "$W/rep.c.raw" >/dev/null 2>&1
  rc=$?
  echo "  $id exit=$rc funcs=$(cat "$R/janus/$id.txt" 2>/dev/null | wc -l)"
done
rm -f "$W"/rep.img "$W"/rep.c "$W"/rep.c.raw
echo "DONE. Next: python $S/hitmap.py"
