#!/bin/bash

NAME="fio-workloads"
TARGET_FS="/mnt/ext4"

# init LTTng session
./lttng/init.sh "$NAME"

# list the fio jobs from jobs directory, and run them one by one
for job in workloads/fio/jobs/*.fio; do
    echo "Running fio job: $job"

    # clear the fio directory before each job to avoid interference from previous runs
    rm -rf $TARGET_FS/*

    # start LTTng tracing for this job
    ./lttng/start.sh "$NAME"

    # run the fio job
    sudo -g ext4_grp fio "$job" --directory=$TARGET_FS

    # stop LTTng tracing and save the trace with a name based on the job file name
    job_name=$(basename "$job" .fio)
    ./lttng/stop.sh "$NAME" "fio_${job_name}"
done

# cleanup LTTng session
./lttng/cleanup.sh "$NAME"
