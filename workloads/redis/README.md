# Redis

First, create a new user for Redis server and add it to `ext4_grp`.

```sh
$ sudo useradd -m -g ext4_grp -s /bin/bash redis_ext4
$ id redis_ext4
# uid=1001(redis_ext4) gid=1002(ext4_grp) groups=1002(ext4_grp)
```

Then, create mounted directories for Redis server.

```sh
sudo mkdir -p /mnt/sdb/redis-data
sudo chown -R redis_ext4:ext4_grp /mnt/sdb/redis-data/
sudo chmod 2775 /mnt/sdb/redis-data
```

Install the Redis server:

```sh
sudo apt-get install redis-server
redis-server --verion
redis-benchmark --version
redis-cli --version
```

Stop the running Redis server to run it manully:

```sh
sudo systemctl stop redis-server
sudo systemctl disable redis-server
sudo systemctl mask redis-server
```

Run the Redis server:

```sh
sudo -u redis_ext4 redis-server redis.conf
sudo -u redis_ext4 nohup redis-server redis.conf > redis.log 2>&1 &
```

Run a sample benchmark:

```sh
redis-benchmark -n 100000 -c 50
```
