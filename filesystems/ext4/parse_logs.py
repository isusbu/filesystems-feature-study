import os
import sys
import glob
from datetime import datetime, timedelta

def shift_time(time_str, seconds_delta):
    """Accurately shifts HH:MM:SS for the 5s lead-in/out padding."""
    try:
        t = datetime.strptime(time_str, "%H:%M:%S")
        new_t = t + timedelta(seconds=seconds_delta)
        return new_t.strftime("%H:%M:%S")
    except Exception:
        return time_str

def get_lower_bound_offset(file_path, target_time):
    """
    STRICT LOWER BOUND: Finds the byte offset of the FIRST line 
    where the timestamp is >= target_time.
    """
    size = os.path.getsize(file_path)
    low, high = 0, size
    best_offset = size 

    with open(file_path, 'rb') as f:
        while low <= high:
            mid = (low + high) // 2
            f.seek(mid)
            f.readline() # Align to start of next full line
            
            line_bytes = f.readline()
            if not line_bytes:
                high = mid - 1
                continue
            
            line = line_bytes.decode('utf-8', errors='ignore')
            try:
                if line.startswith('['):
                    current_ts = line.split(']')[0][1:9] # Extracts HH:MM:SS
                    
                    if current_ts >= target_time:
                        best_offset = mid # Potential candidate, look LEFT
                        high = mid - 1
                    else:
                        low = mid + 1
                else:
                    low = mid + 1
            except (IndexError, ValueError):
                low = mid + 1
                
    return best_offset

def extract_chunk(input_path, output_path, start_off, end_off):
    """Surgically extracts the byte range from the giant trace."""
    length = end_off - start_off
    if length <= 0:
        return

    with open(input_path, 'rb') as infile, open(output_path, 'wb') as outfile:
        infile.seek(start_off)
        remaining = length
        while remaining > 0:
            # 10MB chunks for GPFS efficiency
            chunk = infile.read(min(remaining, 10 * 1024 * 1024))
            if not chunk: break
            outfile.write(chunk)
            remaining -= len(chunk)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 03_break_logs.py <path_to_gpfs_folder>")
        sys.exit(1)
        
    bucket = sys.argv[1]
    giant_log = os.path.join(bucket, "lttng_all_traces.out")
    output_dir = os.path.join(bucket, "split_traces")
    
    # 1. Find the most recent timestamp metadata
    log_pattern = os.path.join(bucket, "timestamps_*.log")
    log_files = glob.glob(log_pattern)
    if not log_files:
        print("Error: No timestamp log found in bucket.")
        return
    
    timestamp_file = max(log_files, key=os.path.getmtime)
    print(f"Using metadata: {os.path.basename(timestamp_file)}")
    os.makedirs(output_dir, exist_ok=True)

    with open(timestamp_file, 'r') as f:
        entries = [l.strip().split(',') for l in f if ',' in l]

    # 2. Slice each test with 5s padding
    for idx, entry in enumerate(entries):
        test_name, start_time_raw = entry
        test_safe_name = test_name.replace("/", "_")
        
        # Lead-in: 5 seconds before logged start
        padded_start = shift_time(start_time_raw, -5)
        
        # Lead-out: 5 seconds after the current test (which is before the next test)
        if idx + 1 < len(entries):
            next_test_start = entries[idx+1][1]
            # Since gap is 15s, ending 5s before the next test 
            # gives you a ~10s lead-out for the current test.
            padded_end = shift_time(next_test_start, -5)
        else:
            padded_end = "23:59:59"

        print(f"--- Slicing {test_name} [Padding: {padded_start} to {padded_end}] ---")
        
        s_off = get_lower_bound_offset(giant_log, padded_start)
        e_off = get_lower_bound_offset(giant_log, padded_end)
        
        if e_off <= s_off:
            e_off = os.path.getsize(giant_log)

        out_path = os.path.join(output_dir, f"trace_{test_safe_name}.out")
        extract_chunk(giant_log, out_path, s_off, e_off)
        print(f"    Saved: {os.path.basename(out_path)} ({e_off - s_off} bytes)")

if __name__ == "__main__":
    main()
