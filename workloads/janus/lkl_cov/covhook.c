/*
 * covhook.c - records which functions run, for the btrfs hit map.
 *
 * btrfs files are compiled with -finstrument-functions, so GCC inserts a call to
 * __cyg_profile_func_enter(fn, caller) at the start of every btrfs function.
 * This hook writes each function address the FIRST time it is seen in a run
 * (as an offset from the program's start, __executable_start) to the file named
 * by $COV_OUT. Writes happen immediately, so data survives even if the run aborts.
 * The hook itself is compiled WITHOUT instrumentation and needs no extra libraries,
 * so it can simply be added into liblkl.a.
 */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define NI __attribute__((no_instrument_function))
#define TBL (1u << 16)

extern char __executable_start;     /* provided by the linker */

static void *seen[TBL];
static int out_fd = -1;
static volatile int state;          /* 0 = not initialised, 1 = initialising, 2 = ready */

NI static void cov_init(void) {
    if (__sync_bool_compare_and_swap(&state, 0, 1)) {
        const char *p = getenv("COV_OUT");
        if (p) out_fd = open(p, O_WRONLY | O_CREAT | O_APPEND, 0644);
        __sync_synchronize();
        state = 2;
    } else {
        while (state != 2) { }
    }
}

NI void __cyg_profile_func_enter(void *fn, void *call_site) {
    (void)call_site;
    if (state != 2) cov_init();
    if (out_fd < 0) return;
    unsigned long h = ((unsigned long)fn >> 4) & (TBL - 1);
    for (unsigned i = 0; i < TBL; i++, h = (h + 1) & (TBL - 1)) {
        void *cur = seen[h];
        if (cur == fn) return;                       /* already recorded */
        if (cur == NULL) {
            if (__sync_bool_compare_and_swap(&seen[h], NULL, fn)) {   /* thread-safe claim */
                char buf[32];
                int n = snprintf(buf, sizeof buf, "%lx\n",
                                 (unsigned long)fn - (unsigned long)&__executable_start);
                if (write(out_fd, buf, n) < 0) { /* ignore */ }
                return;
            }
            if (seen[h] == fn) return;
        }
    }
}

NI void __cyg_profile_func_exit(void *fn, void *call_site) { (void)fn; (void)call_site; }
