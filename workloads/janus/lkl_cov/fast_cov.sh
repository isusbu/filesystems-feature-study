#!/bin/bash
# FAST path (~10 min): recompile ONLY the btrfs files, in place, instead of the whole kernel.
#
# Trick: Linux's build system only recompiles a file if its compile command changed.
# We keep the compiler command string identical to the original Janus build
# ("/usr/src/janus/lkl/../ff-gcc/ff-gcc fs/btrfs") by temporarily swapping the ff-gcc
# binary for a small wrapper, then delete just the btrfs objects. Result: only ~60 btrfs
# files recompile (with function tracking) + relink. The rest of the kernel is reused.
#
# Side effect: fs/btrfs/*.o in the Janus tree become tracking objects. The fuzzing binaries
# you already have (tools/lkl/btrfs-combined etc.) are NOT touched. ff-gcc is restored at the end.
# Run INSIDE the container:  bash /mnt/janus_cov/fast_cov.sh
set -e
J=/usr/src/janus
S=$(dirname "$(readlink -f "$0")")
FF=$J/ff-gcc/ff-gcc
JOBS=${JOBS:-4}

touch "$J/lkl/.wtest" 2>/dev/null && rm -f "$J/lkl/.wtest" || { echo "ERROR: $J/lkl is not writable"; exit 1; }

echo "[1/5] building the tracking hook"
gcc -O2 -fPIC -c "$S/covhook.c" -o "$S/covhook.o"

echo "[2/5] swapping ff-gcc for a tracking wrapper (original saved as ff-gcc.orig)"
[ -f "$FF.orig" ] || cp -p "$FF" "$FF.orig"
cat > "$FF" <<EOF
#!/bin/bash
dir="\$1"; shift
out=""; prev=""; compile=0
for a in "\$@"; do
  [ "\$prev" = "-o" ] && out="\$a"
  case "\$a" in -c|-S|-E) compile=1 ;; esac
  prev="\$a"
done
extra=()
if [ "\$compile" = 1 ] && [[ "\$out" == *"\$dir"* ]]; then extra+=(-finstrument-functions); fi
exec gcc "\$@" "\${extra[@]}"
EOF
chmod +x "$FF"
restore() { cp -p "$FF.orig" "$FF"; }
trap restore EXIT

echo "[3/5] recompiling only fs/btrfs (-j$JOBS). Lines should mostly say fs/btrfs/..."
cd "$J/lkl"
rm -f fs/btrfs/*.o
LOG="$S/fast_build.log"
T="$J/lkl/tools/lkl"
# The tools/lkl Makefile only re-enters the kernel build when lib/lkl.o is missing,
# so remove it (plus the library and executor that depend on it).
rm -f "$T/lib/lkl.o" "$T/liblkl.a" "$T/executor"
set +e
# (a) rebuild the kernel part (only fs/btrfs objects are missing) and liblkl.a
make -C tools/lkl -j"$JOBS" CC="$J/lkl/../ff-gcc/ff-gcc fs/btrfs" "$T/liblkl.a" > "$LOG" 2>&1
rc=$?
# (b) put the hook inside liblkl.a, so the executor link picks it up automatically
[ "$rc" = 0 ] && { ar -rc "$T/liblkl.a" "$S/covhook.o" >> "$LOG" 2>&1; rc=$?; }
# (c) link the executor against the new library
[ "$rc" = 0 ] && { make -C tools/lkl CC="$J/lkl/../ff-gcc/ff-gcc fs/btrfs" "$T/executor" >> "$LOG" 2>&1; rc=$?; }
set -e
echo "make exit code: $rc   (full log: $LOG)"
echo "btrfs files compiled: $(grep -cE '^\s+CC\s+fs/btrfs/' "$LOG")   other kernel files compiled: $(grep -E '^\s+CC\s' "$LOG" | grep -vc 'fs/btrfs/\|tools/lkl')"
if [ "$rc" != 0 ]; then echo "---- last 30 lines of build log ----"; tail -30 "$LOG"; exit 1; fi
cp -f tools/lkl/executor tools/lkl/btrfs-cov-executor
n=$(nm tools/lkl/btrfs-cov-executor | grep -c __cyg_profile_func_enter || true)
echo "hook linked: $n (must be >= 1)"
[ "$n" -ge 1 ] || { echo "ERROR: tracking hook not linked. Last 30 log lines:"; tail -30 "$LOG"; exit 1; }

echo "[4/5] replaying baseline + Janus queue"
W=/mnt/jc_tmp EXE="$J/lkl/tools/lkl/btrfs-cov-executor" bash "$S/replay.sh"

echo "[5/5] building the hit map"
LKL="$J/lkl" EXE="$J/lkl/tools/lkl/btrfs-cov-executor" python "$S/hitmap.py"
