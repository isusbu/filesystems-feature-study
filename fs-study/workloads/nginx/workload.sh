#!/usr/bin/env bash

# check to see if apache-benchmark is installed
if ! command -v ab &> /dev/null
then
    echo "apache-benchmark could not be found, please install it to run this workload."
    exit 1
fi

# use apache-benchmark to send requests to nginx server
ab -n 10000 -c 100 http://localhost/
