# NVIDIA AIStore

NVIDIA AIStore (AIS) is well-known within specific, high-performance technical circles—particularly in AI research, data engineering, and High-Performance Computing (HPC)—rather than to the general public. It is highly regarded as a specialized, open-source, lightweight storage stack designed specifically for AI data pipelines

Reference: [https://github.com/NVIDIA/aistore](https://github.com/NVIDIA/aistore)

Install:

```bash
git clone https://github.com/NVIDIA/aistore.git
cd aistore

# change config at:
cat "deploy/dev/local/aisnode_config.sh"
#
#	"fspaths": {
#		"/mnt/sdc": ""
#	},
#	"test_fspaths": {
#		"root":     "${TEST_FSPATH_ROOT:-/tmp/ais$NEXT_TIER/}",
#		"count":    0,
#		"instance": ${INSTANCE:-0}
#	}
#}

make kill clean cli aisloader deploy

# test
ais show cluster
ais show storage
```

Then run:

```bash
ps -o pid,user,group,cmd -C aisnode
# get output pids for LTTng tracking
```

Now run:

```bash
# Create a bucket
ais create ais://mybucket
# Run a quick benchmark with aisloader: 100% write followed by 50/50%
$ aisloader -bucket=ais://mybucket -duration=10s -numworkers=4 -pctput=100 -cleanup=false
$ aisloader -bucket=ais://mybucket -duration=10s -numworkers=8 -pctput=50 -cleanup=false
```

## Links

- [https://github.com/NVIDIA/aistore/blob/main/docs/getting_started.md](https://github.com/NVIDIA/aistore/blob/main/docs/getting_started.md)
- [https://github.com/NVIDIA/aistore/blob/main/docs/cli/storage.md](https://github.com/NVIDIA/aistore/blob/main/docs/cli/storage.md)
