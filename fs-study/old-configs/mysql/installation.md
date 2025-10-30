# Installation

Installation commands on Ubuntu:

```bash
sudo apt update
sudo apt install mysql-server -y

# copy the mysql config into its config path
cp etc_mysql_mysql.conf.d_mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf

# start mysql instance
sudo systemctl enable mysql
sudo systemctl start mysql
```
