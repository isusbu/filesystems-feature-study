#!/usr/bin/env sh

SESSION="all-syscalls-session"

# filter_logs.sh
# Filters log files to include only lines containing specified keywords.
# Filtering keywords: "procname = \"lttng-consumerd\", "procname = \"lttng\"", and "procname = \"Client manageme\""

# stop the tracing session
sudo lttng stop syscalls-session-"${SESSION}"
sudo lttng destroy syscalls-session-"${SESSION}"
echo "LTTng tracing session 'syscalls-session-${SESSION}' stopped and destroyed."

# convert the trace to a human-readable format
sudo babeltrace2 /tmp/lttng-traces-"${SESSION}" > trace."${SESSION}".txt

# filter the trace file to remove unwanted lines
sudo grep -vE 'procname = "lttng-consumerd"|procname = "lttng"|procname = "Client manageme"' trace."${SESSION}".txt > filtered_trace."${SESSION}".txt
echo "Filtered trace saved to filtered_trace.${SESSION}.txt"

# clean up intermediate trace file
sudo rm trace."${SESSION}".txt
echo "Intermediate trace file trace.${SESSION}.txt removed."
echo "Log filtering completed."
