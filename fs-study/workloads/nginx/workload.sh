#!/usr/bin/env bash

# check to see if apache-benchmark is installed
if ! command -v ab &> /dev/null
then
    echo "apache-benchmark could not be found, please install it to run this workload."
    exit 1
fi

URL=http://localhost


echo "=== Load Test ==="
# use apache-benchmark to send requests to nginx server (1 million requests, concurrency of 2)
ab -n 1000000 -c 2 $URL/

echo "=== Static File ==="
curl -s -o /dev/null -w "%{http_code}\n" $URL/static/test.html

echo "=== Proxy Load Test ==="
wrk -t4 -c50 -d10s $URL/api/ || ab -n 1000 -c 50 $URL/api/

echo "=== Rate Limiting ==="
for i in {1..10}; do curl -s -o /dev/null -w "%{http_code}\n" $URL/api/; done

echo "=== Redirect Test ==="
curl -I $URL/redirect-me

echo "=== Error Page ==="
curl -I $URL/does-not-exist

echo "=== HTTPS Test ==="
curl -k -I https://localhost/

echo "=== Gzip Test ==="
curl -H "Accept-Encoding: gzip" -I $URL/static/test.json
