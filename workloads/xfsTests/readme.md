We need the loop devices to be setup and be ready before running scripts,
those steps are mentioned in filesystems folder for each fs.

We need xfstests repo in /var/tmp to be available

We use set_env.sh to configure the filesystem we are testing, type and number 
of tests we want to perform

We use run_workload.sh to run the workloads while tracing using lttng

All the logs are stored in locations mentioned /tmp/trace_metadata.env

## If the lttng runs for too long, and breaks when probes are added
run this to reset 

sudo killall -9 lttng-sessiond lttng-consumerd

## Specific to nfs

Use this for nfs/001 test
sudo apt update && sudo apt install nfs4-acl-tools -y


