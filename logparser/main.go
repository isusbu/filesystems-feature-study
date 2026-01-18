package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/isusbu/filesystems-feature-study/logparser/internal"
)

func main() {
	// define the program flags
	var (
		initFilePathFlag = flag.String("init", "", "set of keys to import before analysis")
		filePathFlag     = flag.String("file", "log.txt", "log file path")
		groupIdFlag      = flag.Int("gid", 1002, "group id to filter logs")
		workersCountFlag = flag.Int("workers", 5, "number of log parser workers")
	)

	// parse the flags
	flag.Parse()

	// start the workers
	inputChannel := make(chan string, *workersCountFlag)
	workers := make([]*internal.Worker, *workersCountFlag)

	for i := range *workersCountFlag {
		workers[i] = internal.NewWorker(inputChannel)
		go workers[i].Start(*groupIdFlag)

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

	// sum all counts by workers
	counts := createCountsMap(*initFilePathFlag)
	for _, worker := range workers {
		for k, v := range worker.Result() {
			if _, ok := counts[k]; !ok {
				counts[k] = 0
			}

			counts[k] += v
		}
	}

	// write the output into a file
	ofd, err := os.Create(*filePathFlag + ".count")
	if err != nil {
		panic(err)
	}
	defer ofd.Close()

	// write the lines
	for k, v := range counts {
		fmt.Fprintf(ofd, "%s: %d\n", k, v)
	}
}

// create counts map, if input file is given load the set.
func createCountsMap(path string) map[string]int {
	counts := make(map[string]int)

	fd, err := os.Open(path)
	if err == nil {
		// create a scanner
		scanner := bufio.NewScanner(fd)
		for scanner.Scan() {
			line := scanner.Text()
			line = strings.Trim(line, " ")

			counts[line] = 0
		}
	}

	fd.Close()

	return counts
}

// graceful shutdown by stopping the go-routines.
func gracefulShutdown(workers []*internal.Worker) {
	for index, worker := range workers {
		worker.Stop()
		log.Printf("stopped worker: %d\n", index)
	}

	log.Println("graceful shutdown.")
}
