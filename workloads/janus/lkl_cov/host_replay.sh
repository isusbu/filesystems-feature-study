#!/bin/bash
# host_replay.sh - replay Janus inputs on the REAL kernel and count which btrfs functions run.
#
# Run on the VM (not inside the container), as root:
#     sudo bash ~/sravya/replay/host_replay.sh [N]      # N = how many queue inputs (default 20)
#
# Layout (the folder this script lives in, bind-mounted into container 'janus2' at /replay):
#     queue/              Janus queue files (copied from SeaWulf)
#     results/baseline/   per seed program: function<TAB>hits
#     results/janus/      per queue input:  function<TAB>hits
#     results/summary.txt totals + bloat candidates (btrfs functions never hit)
#
# How: the container (old toolchain) only DECODES each input into image + C program.
# The host mounts the image with the real btrfs module, runs the program inside the mount,
# and the ftrace FUNCTION PROFILER counts hits per btrfs function (no trace log is written).
set -u
R=$(dirname "$(readlink -f "$0")")
C=${C:-janus2}
N=${1:-20}
OUT=$R/results
MNT=$R/mnt
T=/sys/kernel/tracing

die() { echo "ERROR: $*"; exit 1; }
[ "$(id -u)" = 0 ] || die "run with sudo"
grep -q '^CONFIG_FUNCTION_PROFILER=y' /boot/config-"$(uname -r)" || die "kernel lacks CONFIG_FUNCTION_PROFILER"
[ -e $T/function_profile_enabled ] || mount -t tracefs nodev $T 2>/dev/null
[ -e $T/function_profile_enabled ] || T=/sys/kernel/debug/tracing
[ -e $T/function_profile_enabled ] || die "tracefs not found"
[ "$(docker inspect -f '{{.State.Running}}' $C 2>/dev/null)" = true ] || die "container $C is not running"
[ -d "$R/queue" ] || die "no queue folder at $R/queue"
if findmnt -t btrfs -n >/dev/null; then die "another btrfs is mounted on this VM; its activity would pollute the counts"; fi

modprobe btrfs || die "cannot load btrfs module"
mkdir -p "$OUT/baseline" "$OUT/janus" "$MNT" "$R/seeds"

# trace only btrfs functions
echo 0 > $T/function_profile_enabled
echo ':mod:btrfs' > $T/set_ftrace_filter || die "could not set btrfs filter"
grep '\[btrfs\]' $T/available_filter_functions | awk '{print $1}' | sort -u > "$OUT/traceable_btrfs.txt"
echo "traceable btrfs functions: $(wc -l < "$OUT/traceable_btrfs.txt")"

collect() {   # sum hits over all CPUs -> function<TAB>hits
  cat $T/trace_stat/function* 2>/dev/null | awk '$1!="Function" && $1 !~ /^-/ && NF>=2 {h[$1]+=$2} END {for (f in h) print f "\t" h[f]}' | sort > "$1"
}

run_one() {   # $1 image  $2 C program  $3 output file
  local img=$1 src=$2 out=$3 loop status rc
  gcc -w -o "$R/cur_prog" "$src" 2>/dev/null || { echo "compile-failed"; return; }
  echo 0 > $T/function_profile_enabled
  echo 1 > $T/function_profile_enabled          # re-enabling resets the counters
  loop=$(losetup -f --show "$img") || { echo 0 > $T/function_profile_enabled; echo "no-loop-device"; return; }
  if timeout 30 mount -t btrfs "$loop" "$MNT" 2>/dev/null; then
    (cd "$MNT" && timeout 30 "$R/cur_prog" >/dev/null 2>&1); rc=$?
    timeout 30 umount "$MNT" 2>/dev/null || umount -l "$MNT"
    status="mounted prog_exit=$rc"
  else
    status="mount-rejected"
  fi
  losetup -d "$loop" 2>/dev/null
  echo 0 > $T/function_profile_enabled
  collect "$out"
  echo "$status funcs=$(wc -l < "$out")"
}

echo "== decoding seed programs in the container =="
docker exec $C bash -c 'cd /usr/src/janus && for p in prog/*; do ./core/program_show $p > /replay/seeds/$(basename $p).c; done; cp samples/evaluation/btrfs-00.image /replay/seed.orig' \
  || die "seed export failed"

echo "== baseline: seed programs on the unmodified image =="
for c in "$R"/seeds/*.c; do
  n=$(basename "$c" .c)
  cp "$R/seed.orig" "$R/cur.img"
  echo "  $n: $(run_one "$R/cur.img" "$c" "$OUT/baseline/$n.tsv")"
done

echo "== janus queue: first $N inputs =="
for f in $(ls "$R/queue" | grep '^id:' | sort | head -n "$N"); do
  id=${f%%,*}
  rm -f "$R"/cur.img "$R"/cur.c "$R"/cur.c.raw
  if ! docker exec $C bash -c "cd /usr/src/janus && ./utils/afl-parse -i samples/evaluation/btrfs-00.image -t btrfs -f '/replay/queue/$f' -o /replay/cur" >/dev/null 2>&1; then
    echo "  $id: decode-failed"; continue
  fi
  echo "  $id: $(run_one "$R/cur.img" "$R/cur.c" "$OUT/janus/$id.tsv")"
done
rm -f "$R"/cur.img "$R"/cur.c "$R"/cur.c.raw "$R/cur_prog"
echo > $T/set_ftrace_filter

# summary: which traceable btrfs functions were hit, and which never were (bloat candidates)
cat "$OUT"/baseline/*.tsv 2>/dev/null | awk '$2>0{print $1}' | sort -u > "$OUT/hit_baseline.txt"
cat "$OUT"/janus/*.tsv    2>/dev/null | awk '$2>0{print $1}' | sort -u > "$OUT/hit_janus.txt"
sort -u "$OUT/hit_baseline.txt" "$OUT/hit_janus.txt" > "$OUT/hit_any.txt"
comm -23 "$OUT/traceable_btrfs.txt" "$OUT/hit_any.txt" > "$OUT/never_hit.txt"
comm -13 "$OUT/hit_baseline.txt" "$OUT/hit_janus.txt" > "$OUT/janus_only.txt"
{
  echo "kernel: $(uname -r)"
  echo "traceable btrfs functions : $(wc -l < "$OUT/traceable_btrfs.txt")"
  echo "hit by baseline (seeds)   : $(wc -l < "$OUT/hit_baseline.txt")"
  echo "hit by Janus inputs       : $(wc -l < "$OUT/hit_janus.txt")"
  echo "hit by Janus, not baseline: $(wc -l < "$OUT/janus_only.txt")"
  echo "never hit (bloat candidates, traceable only): $(wc -l < "$OUT/never_hit.txt")"
} | tee "$OUT/summary.txt"
echo "lists: $OUT/never_hit.txt, janus_only.txt"
