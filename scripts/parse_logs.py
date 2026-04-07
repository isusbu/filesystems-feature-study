import os
import sys
import glob
from datetime import datetime, timedelta

def shift_time(full_time_str, seconds_delta):
    """
    Shifts a YYYY-MM-DD HH:MM:SS string by seconds.
    Handles date rollovers (midnight) automatically.
    """
    try:
        t = datetime.strptime(full_time_str, "%Y-%m-%d %H:%M:%S")
        new_t = t + timedelta(seconds=seconds_delta)
        return new_t.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return full_time_str

def get_lower_bound_offset(file_path, target_hms):
    """
    Binary Search to find the byte offset where log timestamp >= target_hms.
    Expects log lines starting with [HH:MM:SS.ns]
    """
    if not os.path.exists(file_path):
        return 0

    size = os.path.getsize(file_path)
    low, high = 0, size
    best_offset = size

    with open(file_path, 'rb') as f:
        while low <= high:
            mid = (low + high) // 2
            f.seek(mid)
            f.readline() # Sync to start of next full line

            line_bytes = f.readline()
            if not line_bytes:
                high = mid - 1
                continue

            line = line_bytes.decode('utf-8', errors='ignore')
            try:
                if line.startswith('['):
                    # Extract: HH:MM:SS (8 chars) from [HH:MM:SS.xxxxxx]
                    current_hms = line.split(']')[0][1:9]

                    if current_hms >= target_hms:
                        # Success: this line is at or after target. Look left.
                        best_offset = f.tell() - len(line_bytes)
                        high = mid - 1
                    else:
                        # This line is too early. Look right.
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
        print("    Warning: Range invalid or no data (0 bytes).")
        return

    with open(input_path, 'rb') as infile, open(output_path, 'wb') as outfile:
        infile.seek(start_off)
        remaining = length
        while remaining > 0:
            chunk = infile.read(min(remaining, 10 * 1024 * 1024))
            if not chunk:
                break
            outfile.write(chunk)
            remaining -= len(chunk)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 parse_logs.py <path_to_gpfs_folder>")
        sys.exit(1)

    bucket = os.path.abspath(sys.argv[1])
    giant_log = os.path.join(bucket, "lttng_all_traces.out")
    output_dir = os.path.join(bucket, "split_traces")

    if not os.path.exists(giant_log):
        print(f"Error: Giant log not found at {giant_log}")
        sys.exit(1)

    log_pattern = os.path.join(bucket, "timestamps_*.log")
    log_files = glob.glob(log_pattern)
    if not log_files:
        print("Error: No timestamp log found in bucket.")
        return

    timestamp_file = max(log_files, key=os.path.getmtime)
    file_mtime = datetime.fromtimestamp(os.path.getmtime(timestamp_file))
    date_anchor = file_mtime.strftime("%Y-%m-%d")

    print(f"Using metadata: {os.path.basename(timestamp_file)}")
    print(f"Date Anchor: {date_anchor}")

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    entries = []
    with open(timestamp_file, 'r') as f:
        for line in f:
            if ',' in line:
                name, hms = line.strip().split(',')
                full_ts = f"{date_anchor} {hms}"
                entries.append((name, full_ts))

    for idx, entry in enumerate(entries):
        test_name, start_time_full = entry
        test_safe_name = test_name.replace("/", "_")

        # Padded start (HH:MM:SS)
        padded_start_full = shift_time(start_time_full, -5)
        search_start_hms = padded_start_full.split(' ')[1]

        if idx + 1 < len(entries):
            next_test_start = entries[idx+1][1]
            padded_end_full = shift_time(next_test_start, -5)
            
            if padded_end_full < padded_start_full:
                padded_end_full = shift_time(padded_end_full, 86400)
            
            search_end_hms = padded_end_full.split(' ')[1]
        else:
            search_end_hms = "23:59:59" # Final test uses EOF fallback

        print(f"--- Slicing {test_name} [{search_start_hms} to {search_end_hms}] ---")

        s_off = get_lower_bound_offset(giant_log, search_start_hms)
        e_off = get_lower_bound_offset(giant_log, search_end_hms)

        if e_off <= s_off:
            e_off = os.path.getsize(giant_log)

        out_path = os.path.join(output_dir, f"trace_{test_safe_name}.out")
        extract_chunk(giant_log, out_path, s_off, e_off)
        print(f"    Saved: {os.path.basename(out_path)} ({e_off - s_off} bytes)")

if __name__ == "__main__":
    main()

