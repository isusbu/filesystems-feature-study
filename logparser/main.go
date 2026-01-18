package main

import (
	"bufio"
	"flag"
	"log"
	"os"
	"time"

	"github.com/isusbu/filesystems-feature-study/logparser/internal"
)

func main() {
	// define the program flags
	var (
		filePathFlag     = flag.String("file", "log.txt", "log file path")
		workersCountFlag = flag.Int("workers", 5, "number of log parser workers")
	)

	// parse the flags
	flag.Parse()

	// start the workers
	inputChannel := make(chan string, *workersCountFlag)
	workers := make([]*internal.Worker, *workersCountFlag)

	for i := range *workersCountFlag {
		workers[i] = internal.NewWorker(inputChannel)
		go workers[i].Start()

		log.Printf("start worker %d\n", i)
	}
	defer gracefulShutdown(workers)

	// read the file and pass the lines to workers
	fd, err := os.Open(*filePathFlag)
	if err != nil {
		panic(err)
	}
	defer fd.Close()

	// create a scanner
	scanner := bufio.NewScanner(fd)
	for scanner.Scan() {
		line := scanner.Text()
		inputChannel <- line
	}

	// check for scanner errors
	if err := scanner.Err(); err != nil {
		panic(err)
	}

	// wait until the input channel is empty
	log.Println("input channel check.")
	for {
		if len(inputChannel) == 0 {
			break
		}

		time.Sleep(1 * time.Second)
	}
}

// graceful shutdown by stopping the go-routines.
func gracefulShutdown(workers []*internal.Worker) {
	for index, worker := range workers {
		worker.Stop()
		log.Printf("stopped worker: %d\n", index)
	}

	log.Println("graceful shutdown.")
}
