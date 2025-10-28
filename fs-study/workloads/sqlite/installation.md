# Installation

Installation commands on Ubuntu:

```bash
# copy the schema and workload files
cp etc_sqlite3_test.schema.sql /etc/sqlite3/test_schema.sql
cp etc_sqlite3_workload.sql /etc/sqlite3/workload.sql

# execute them
sqlite3 test.db < /etc/sqlite3/test_schema.sql
sqlite3 test.db < /etc/sqlite3/workload.sql
```
