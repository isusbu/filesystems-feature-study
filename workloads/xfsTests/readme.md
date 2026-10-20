set_env.sh creates its own sparse image files in /srv/xfstests_imgs (6G each;
IMG_DIR and IMG_SIZE override) and attaches them to free loop devices, so no
loop device setup is needed. run_workload.sh refuses to format a loop device
that is not backed by one of these images.

For btrfs, set_env.sh also adds 4 pool images as SCRATCH_DEV_POOL, needed by
multi-device tests (POOL_EXTRA overrides the count, 0 disables it).

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


