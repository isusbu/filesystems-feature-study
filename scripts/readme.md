Workflow

1. set_env.sh (Configuration)

This script initializes the experiment metadata.

Function: Prompts for the target filesystem (FSTYP), test range, and batch name.

Output: Generates /tmp/trace_metadata.env, which synchronizes the tracer and the workload runner.

2. run_workload.sh (Execution)

The main driver script that manages the hardware and the tracer.

Function: 
1. Attaches loop devices to private 10GB sparse images.
2. Wipes and formats TEST_DEV and SCRATCH_DEV to ensure a clean state.
3. Triggers lttng/init.sh to attach specific kernel probes (kprobes).
4. Runs the xfstests suite via ./check.
5. Aggregates and moves the giant LTTng trace to GPFS storage.
6. timestamps_xfsTests_[FSTYP]_[FOLDER]_[START]_to_[END]_[DATE].log this file helps in noting the start time of each test

![alt text](image.png)

3. parse_logs.py (Post-Processing)

A Python utility to slice the massive aggregate log into individual test traces.

Logic: Uses binary search for fast offset lookup within multi-gigabyte files.

Padding: Adds a 5-second lead-in and a 5-second lead-out to each trace to capture background metadata flushing or delayed journal commits.

Usage: python3 parse_logs.py /path/to/gpfs/batch_folder/

4. logparser (Counts)

The repository also includes a Go-based log parser in `logparser/` which produces `.count` files (function-call counts) from an LTTng text trace.

It is already invoked by `lttng/cleanup.sh` (as `lp`) to generate a single count file for the full session trace. If you split the session trace with `parse_logs.py`, you can run the same parser on each `split_traces/trace_*.out` file to get per-test counts.

Example (build `lp` once, then run on a single trace):

```sh
cd logparser
go build -o lp .
./lp -file /path/to/logs/split_traces/trace_ext4_001.out -init /path/to/logs/hooked_global.txt -gid 1002
```

Use scripts/count_functions_in_lttng_logs.sh for generating count files after batch test

Logs Storage Structure

All results are stored on GPFS at /mnt/gpfs/fs-study/${USER_NAME}/${FILE_SYSTEM}/logs following this hierarchy:

xfstests_logs/: Raw console output from xfstests.

lttng_all_traces.out: The complete, raw binary-to-text trace of the entire batch.

split_traces/: Surgically extracted .out files per test (e.g., trace_f2fs_006.out).

timestamps_*.log: Metadata mapping test names to the clock time they started.

hooked_global.txt: Hooked probes for this batch

failed_global.txt: Failed probes for this batch

Extra setup -  Notes

Loop Devices: Uses /dev/loop10 (Test) and /dev/loop11 (Scratch).

Permissions: Log files in ../lttng/ are set to 666 to allow the root-owned tracer to write to user-owned directories on the FSL cluster.

Tracing: Probes are defined in ../lttng/filesystems/{FSTYP}/kprobes.txt.
