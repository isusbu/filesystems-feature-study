#!/bin/bash

METADATA_FILE="/tmp/trace_metadata.env"
if [ ! -f "$METADATA_FILE" ]; then
    echo "Error: Metadata file $METADATA_FILE not found."
    exit 1
fi
source "$METADATA_FILE" 

PARSER_DIR="/home/satche/filesystems-feature-study/logparser"
GID=1002

cd "$PARSER_DIR" || { echo "Failed to enter $PARSER_DIR"; exit 1; }

echo "Building Log Parser (Go) in $PARSER_DIR..."
go build -o lp .
if [ $? -ne 0 ]; then
    echo "Error: Go build failed."
    exit 1
fi

# Define paths based on the metadata from trace_metadata.env
TRACE_DIR="$OUTPUT_DIR/split_traces" 
HOOKED_FILE="$OUTPUT_DIR/hooked_global.txt" 

if [ ! -d "$TRACE_DIR" ]; then
    echo "Error: Trace directory $TRACE_DIR does not exist."
    exit 1
fi

echo "Processing Batch: $BATCH_NAME" 
echo "Input directory: $TRACE_DIR" 

# Generate .count files for all .out files
for trace_file in "$TRACE_DIR"/trace_*.out; do
    [ -e "$trace_file" ] || continue

    ./lp -file "$trace_file" -init "$HOOKED_FILE" -gid "$GID"
    
    if [ $? -eq 0 ]; then
        echo "Done: $(basename "$trace_file").count generated." 
    else
        echo "FAIL: Could not process $(basename "$trace_file")"
    fi
done

echo "All traces for $BATCH_NAME have been processed to generate count of functions."