# Installation

Installation commands on Ubuntu:

```bash
sudo apt update
sudo apt install sqlite3 sqlite3-doc -y

# copy the config file into the instance
cp etc_sqlite3_sqlite.init.sql /etc/sqlite3/sqlite_init.sql

# apply the changes
sqlite3 test.db < /etc/sqlite3/sqlite_init.sql
```
