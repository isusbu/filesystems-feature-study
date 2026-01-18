package internal

import (
	"fmt"
	"sync"
)

// Worker gets a log line and counts the function call.
type Worker struct {
	memory *MemCache

	input chan string
	term  chan int

	wg *sync.WaitGroup
}

// NewWorker returns a worker instance.
func NewWorker(input chan string, term chan int) *Worker {
	return &Worker{
		memory: &MemCache{
			counts: make(map[string]int),
		},
		input: input,
		term:  term,
		wg:    &sync.WaitGroup{},
	}
}

// Start worker main loop.
func (w *Worker) Start() {
	defer w.wg.Done()
	w.wg.Add(1)

	for {
		select {
		case <-w.term:
			return
		case data := <-w.input:
			fmt.Println(data)
		}
	}
}

// Stop the running worker.
func (w *Worker) Stop() {
	w.term <- 1
	w.wg.Wait()
}
