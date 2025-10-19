#!/usr/bin/env bash
# analysis syscall tracing results of trace-syscalls.sh
# the output of trace-syscall.sh should be in tracing.out
# this script will generate result.txt with the analysis result

# get all systemcalls that we are tracing
sudo bpftrace -l 'tracepoint:syscalls:sys_enter_*' | sed 's/.*sys_enter_//' > all_syscalls.txt

# parse the tracing results into systemcall name only
grep -oP 'sys_enter_\K[[:alnum:]_]+' tracing.out | sort -u > observed_syscalls.txt

# compare the results
ALL=$(wc -l < all_syscalls.txt)
OBS=$(wc -l < observed_syscalls.txt)
printf "Observed %d / %d syscalls = %.2f%%\n" "$OBS" "$ALL" "$(awk -v o=$OBS -v a=$ALL 'BEGIN{printf 100*o/a}')" > result.txt
