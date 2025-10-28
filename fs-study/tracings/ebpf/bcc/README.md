# BCC

To compile this code and use it to trace all syscalls in a Linux system, use this command:

```bash
gcc -o trace_syscalls_user trace_syscalls_user.c -lbpf -lelf -pthread
```
