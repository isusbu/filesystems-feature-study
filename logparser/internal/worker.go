package internal

import (
	"regexp"
	"strconv"
	"strings"
	"sync"
)

var (
	re = regexp.MustCompile(
		`(\w+):.*procname = "([^"]+)".*gid = (\d+)`,
	)
)

// Worker gets a log line and counts the function call.
type Worker struct {
	memory *MemCache

	input chan string
	term  chan int

	wg *sync.WaitGroup
}

// NewWorker returns a worker instance.
func NewWorker(input chan string) *Worker {
	return &Worker{
		memory: &MemCache{
			counts: make(map[string]int),
		},
		input: input,
		term:  make(chan int),
		wg:    &sync.WaitGroup{},
	}
}

// Start worker main loop.
func (w *Worker) Start(gid int) {
	defer w.wg.Done()
	w.wg.Add(1)

	for {
		select {
		case <-w.term:
			return
		case data := <-w.input:
			// must pass regrex
			match := re.FindStringSubmatch(data)
			if len(match) == 4 {
				procname := strings.ToLower(match[2])

				// skip all lttng procs
				if strings.Contains(procname, "lttng") {
					continue
				}

				// group id must match
				tgid, _ := strconv.Atoi(match[3])
				if gid == tgid {
					w.memory.Inc(match[1])
				}
			}
		}
	}
}

// Stop the running worker.
func (w *Worker) Stop() {
	w.term <- 1
	w.wg.Wait()
}
