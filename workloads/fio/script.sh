#!/bin/bash

NAME="fio-workloads"

# init LTTng session
./lttng/init.sh "$NAME"

# list the fio jobs from jobs directory, and run them one by one
for job in jobs/*.fio; do
    echo "Running fio job: $job"

    # start LTTng tracing for this job
    ./lttng/start.sh "$NAME"

    # run the fio job
    sudo fio "$job" --directory=/mnt/ext4

    # stop LTTng tracing and save the trace with a name based on the job file name
    job_name=$(basename "$job" .fio)
    ./lttng/stop.sh "$NAME" "fio_${job_name}"
done

# cleanup LTTng session
./lttng/cleanup.sh "$NAME"
