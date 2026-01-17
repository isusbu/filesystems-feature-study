// trace_syscalls.bpf.c
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <linux/ptrace.h>

struct event {
    __u32 pid;
    __u32 syscall_id;
    char comm[32];
};

struct trace_event_raw_sys_enter {
    __u64 common_tp_fields;  // tracepoint common fields start
    __u64 unused;            // padding to align (varies)
    __u64 id;                // syscall id
    unsigned long args[6];   // syscall arguments
};

struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 1 << 24);
} events SEC(".maps");

SEC("tracepoint/raw_syscalls/sys_enter")
int trace_sys_enter(struct trace_event_raw_sys_enter *ctx) {
    struct event *e;
    e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e)
        return 0;

    e->pid = bpf_get_current_pid_tgid() >> 32;
    e->syscall_id = ctx->id;
    bpf_get_current_comm(&e->comm, sizeof(e->comm));

    bpf_ringbuf_submit(e, 0);
    return 0;
}

char LICENSE[] SEC("license") = "GPL";
