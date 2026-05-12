# SQLite

1.Create a new group and dedicated user for SQLite tracing (GID Tracking).

```sh
$ sudo groupadd -g 1002 sqlite_trace
$ sudo useradd -m -g sqlite_trace -s /bin/bash sqlite_user
$ id sqlite_user
# uid=XXXX(sqlite_user) gid=1002(sqlite_trace) groups=1002(sqlite_trace)
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

