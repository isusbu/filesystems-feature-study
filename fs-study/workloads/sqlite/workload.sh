#!/usr/bin/env bash

# check to see if apache-benchmark is installed
if ! command -v sqlite3 &> /dev/null
then
    echo "apache-benchmark could not be found, please install it to run this workload."
    exit 1
fi

for i in {1..1000}; do
  sqlite3 test.db "INSERT INTO users (name, email) VALUES ('User$i', 'user$i@example.com');"
  sqlite3 test.db "INSERT INTO posts (user_id, title, content, tags) VALUES ($((i%2+1)), 'Post$i', 'Load test content', 'test');"
done

echo "Inserted 1000 records into the database."
