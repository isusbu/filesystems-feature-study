# SQLite

1.Create a new group and dedicated user for SQLite tracing (GID Tracking).

```sh
$ sudo groupadd -g GID sqlite_trace
$ sudo useradd -m -g sqlite_trace -s /bin/bash sqlite_user
$ id sqlite_user
# uid=XXXX(sqlite_user) gid=GID(sqlite_trace) groups=GRP(sqlite_trace)
```


2.Install SQLite:

```sh
sudo apt-get install sqlite3
sqlite3 --version
```

3.Verify SQLite is available:

```sh
which sqlite3
```

4.Run SQLite as the dedicated user:

```sh
sudo -u sqlite_user sqlite3
```

# SQLite Benchmark Setup
sqlite-bench is a db_bench-style benchmark tool for SQLite. It calls SQLite3 library functions directly  to carry out SQLite operations.
Once SQLite is installed, build sqlite-bench to run benchmark workloads against it:

##  Build sqlite-bench

```bash

git clone https://github.com/ukontainer/sqlite-bench.git


# Compile all source files
cc -Wall -I. -O2 -DNDEBUG -std=c99 -c benchmark.c
cc -Wall -I. -O2 -DNDEBUG -std=c99 -c histogram.c
cc -Wall -I. -O2 -DNDEBUG -std=c99 -c main.c
cc -Wall -I. -O2 -DNDEBUG -std=c99 -c random.c
cc -Wall -I. -O2 -DNDEBUG -std=c99 -c raw.c
cc -Wall -I. -O2 -DNDEBUG -std=c99 -c sqlite3.c
cc -Wall -I. -O2 -DNDEBUG -std=c99 -c util.c

# Link all object files into sqlite-bench binary
cc benchmark.o histogram.o main.o random.o raw.o sqlite3.o util.o \
    -o sqlite-bench -lpthread -ldl -lm

# Install to PATH
sudo mv sqlite-bench /usr/local/bin/
```






