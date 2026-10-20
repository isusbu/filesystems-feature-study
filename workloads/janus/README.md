# Janus inputs as an LTTng workload

[Janus](https://github.com/sslab-gatech/janus) is a file system fuzzer. It runs the kernel inside LKL, so host tracers cannot see it. Here Janus only generates and decodes inputs. Each input (a disk image plus a syscall program) is replayed on the host kernel, and the usual LTTng setup counts which file system functions it reaches.

## Requirements

- A running Janus container built for the target file system, with `/srv/janus_replay` mounted at `/replay`
- The fuzzing output (`queue/` and `fuzzer_stats`) under `/srv/janus_replay`
- `filesystems/<fs>/kprobes.txt`, the `ext4_grp` group and the LTTng setup from the main README

## Run

From the repo root, on the VM:

```sh
# once per kernel: map LKL syscall names to x86_64 names (writes /srv/janus_replay/syscall_compat.h)
sudo C=janus-ext4 bash workloads/janus/gen_syscall_map.sh

# replay the seed programs, then the queue in 30-minute windows of fuzzing time, 500 inputs per LTTng session
sudo bash workloads/janus/run_replay_windows.sh --fs ext4 --seed ext4-00.image \
     --queue /srv/janus_replay/fuzz_out_ext4_00/ext4_00/queue --prog /replay/prog_ext4_00 \
     --tag e00 --window 30 --windows 6 --batch 500 --pause 3 --pause-rejected 1 \
     --container janus-ext4
```

Counts land in `/mnt/gpfs/fs-study/<fs>-session-<tag>_base` (seed programs) and `<fs>-session-<tag>_w<W>_b<K>` (window W, batch starting at input K). The log is `/srv/janus_replay/replay_<tag>_<date>.log`.

`lttng_workload.sh` replays a single batch and can be run on its own between `lttng/start.sh` and `lttng/stop.sh`; see `--help`.

## Notes

- The LTTng session daemon is restarted before every session, because destroying a session can kill `lttng-consumerd` and later sessions then record nothing. "A session daemon is already running" during the restart is harmless.
- To resume after an interruption: `--skip-baseline --first-window W`.
- Ids listed in `/srv/janus_replay/skip_ids.txt` (one per line, e.g. `id:001557`) are not replayed. The file applies to any queue, so move it aside before replaying a different run.
