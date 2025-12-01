#!/bin/sh

# Function to check lttng existence
cexists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for lttng
if cexists "lttng"; then
    echo "lttng found!"
else
    echo "please install lttng!!"
    exit 1
fi

SUFFIX=$1
SESSION_NAME="ext4-session-${SUFFIX}"
OUTPUT_DIR="/tmp/lttng-traces/${SESSION_NAME}"

# Create session
lttng create "$SESSION_NAME" -o "$OUTPUT_DIR"
lttng enable-channel --kernel channel0 \
  --subbuf-size=8M \
  --num-subbuf=16

lttng add-context --kernel --type procname
lttng add-context --kernel --type pid
lttng add-context --kernel --type tid
lttng add-context --kernel --type callstack-kernel

# File with tracepoints
TP_FILE="tracepoints.txt"

if [ ! -f "$TP_FILE" ]; then
    echo "Missing file: $TP_FILE"
    exit 1
fi

# Read tracepoints line-by-line
while IFS= read -r tp; do
    # Skip empty or commented lines
    case "$tp" in
        ""|\#*) continue ;;
    esac

    echo "Enabling kernel probe for: $tp"
    lttng enable-event --channel=channel0 --kernel --probe="$tp" "$tp"
done < "$TP_FILE"

echo "session built."
echo "run: sudo lttng start --session=$SESSION_NAME"
echo "execute your workload ..."
echo "run: sudo lttng stop --session=$SESSION_NAME"
echo "run: sudo lttng destroy --session=$SESSION_NAME"
echo "output at: $OUTPUT_DIR"
echo "use: babeltrace2 $OUTPUT_DIR"
echo "happy life!"
