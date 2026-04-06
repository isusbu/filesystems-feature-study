import os
import sys
import glob
from collections import Counter

def process_traces(logs_dir):
    split_dir = os.path.join(logs_dir, "split_traces")
    hooked_file = os.path.join(logs_dir, "hooked_global.txt")
    
    if not os.path.exists(hooked_file):
        print(f"Error: Hooked list not found at {hooked_file}")
        return

    # Load master list of functions
    with open(hooked_file, 'r') as f:
        hooked_functions = sorted([line.strip() for line in f if line.strip()])

    # Detect prefix (e.g., ext4_)
    prefix = hooked_functions[0].split('_')[0] + "_" if hooked_functions else "ext4_"

    # Find all .out trace files
    trace_files = glob.glob(os.path.join(split_dir, "trace_*.out"))
    
    for trace_path in trace_files:
        count_path = trace_path + ".count"
        
        # --- CLEANUP STEP ---
        # Explicitly remove the old count file if it exists to prevent any corruption
        if os.path.exists(count_path):
            os.remove(count_path)

        counts = Counter()

        # Parse the .out file
        with open(trace_path, 'r', errors='ignore') as f:
            for line in f:
                if ']' not in line: continue
                
                parts = line.split()
                # Flexible parsing: find the word with the prefix ending in a colon
                for part in parts:
                    if prefix in part and part.endswith(':'):
                        func_name = part.rstrip(':')
                        counts[func_name] += 1
                        break 

        # Write fresh counts
        with open(count_path, 'w') as out_f:
            for func in hooked_functions:
                out_f.write(f"{func}: {counts[func]}\n")
        
        print(f"Verified & Saved: {os.path.basename(count_path)}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 count_functions.py <path_to_logs_folder>")
        sys.exit(1)
    process_traces(sys.argv[1])
