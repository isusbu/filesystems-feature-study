// trace_syscalls_user.c
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>

struct event {
    __u32 pid;
    __u32 syscall_id;
    char comm[16];
};

static volatile bool exiting = false;

static void handle_event(void *ctx, void *data, size_t data_sz) {
    struct event *e = data;

    // Drop events from unwanted processes
    if (strncmp(e->comm, "sshd", 4) == 0) return;
    if (strncmp(e->comm, "sudo", 4) == 0) return;
    if (strncmp(e->comm, "trace_syscalls_", 15) == 0) return;

    printf("PID %d (%s) called syscall ID %u\n", e->pid, e->comm, e->syscall_id);
}

static void handle_lost_events(void *ctx, uint64_t lost_cnt) {
    fprintf(stderr, "Lost %llu events\n", lost_cnt);
}

static void sig_handler(int sig) {
    exiting = true;
}

int main(int argc, char **argv) {
    struct ring_buffer *rb = NULL;
    struct bpf_object *obj;
    int err;

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    obj = bpf_object__open_file("trace_syscalls.bpf.o", NULL);
    if (libbpf_get_error(obj)) {
        fprintf(stderr, "Failed to open BPF object\n");
        return 1;
    }

    err = bpf_object__load(obj);
    if (err) {
        fprintf(stderr, "Failed to load BPF object\n");
        return 1;
    }

    // Attach tracepoint program automatically
    struct bpf_program *prog = bpf_object__find_program_by_name(obj, "trace_sys_enter");
    if (!prog) {
        fprintf(stderr, "Program not found\n");
        return 1;
    }

    struct bpf_link *link = bpf_program__attach(prog);
    if (libbpf_get_error(link)) {
        fprintf(stderr, "Failed to attach program\n");
        return 1;
    }

    int map_fd = bpf_object__find_map_fd_by_name(obj, "events");
    if (map_fd < 0) {
        fprintf(stderr, "Failed to find map fd\n");
        return 1;
    }

    rb = ring_buffer__new(map_fd, handle_event, NULL, NULL);
    if (!rb) {
        fprintf(stderr, "Failed to create ring buffer\n");
        return 1;
    }

    printf("Tracing syscalls... Ctrl+C to stop.\n");

    while (!exiting) {
        err = ring_buffer__poll(rb, 100 /* ms */);
        if (err < 0) {
            fprintf(stderr, "Error polling ring buffer: %d\n", err);
            break;
        }
    }

    ring_buffer__free(rb);
    bpf_link__destroy(link);
    bpf_object__close(obj);

    return 0;
}
