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

3. parse_logs.py (Post-Processing)

A Python utility to slice the massive aggregate log into individual test traces.

Logic: Uses binary search for fast offset lookup within multi-gigabyte files.

Padding: Adds a 5-second lead-in and a 5-second lead-out to each trace to capture background metadata flushing or delayed journal commits.

Usage: python3 parse_logs.py /path/to/gpfs/batch_folder/

Logs Storage Structure

All results are stored on GPFS at /mnt/gpfs/fs-study/sravya/ following this hierarchy:

testing_logs/: Raw console output from xfstests.

lttng_all_traces.out: The complete, raw binary-to-text trace of the entire batch.

split_traces/: Surgically extracted .out files per test (e.g., trace_f2fs_006.out).

timestamps_*.log: Metadata mapping test names to the clock time they started.

Extra setup -  Notes

Loop Devices: Uses /dev/loop10 (Test) and /dev/loop11 (Scratch).

Permissions: Log files in ../lttng/ are set to 666 to allow the root-owned tracer to write to user-owned directories on the FSL cluster.

Tracing: Probes are defined in ../lttng/filesystems/{FSTYP}/kprobes.txt.
