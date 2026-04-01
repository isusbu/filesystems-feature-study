# Dbench commands

### Standard & Concurrency Tests

**1\. Baseline**

- **Name:** `dbench_16c_30s_baseline`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 16
```

**2\. Soak Test**

- **Name:** `dbench_10c_60s_soak`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 60 10
```

**3\. High-Concurrency Stress Test**

- **Name:** `dbench_64c_30s_stress`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 64
```

**4\. Single-Client Latency Test**

- **Name:** `dbench_1c_30s_single`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 1
```

**5\. Extreme Concurrency (Lock Contention Profiling)**

- **Name:** `dbench_256c_30s_extreme`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 256
```

**6\. Extended Cache Thrashing (Writeback Trigger)**

- **Name:** `dbench_32c_300s_thrash`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 300 32
```

* * *

### Sync & Journaling Tests

**7\. Sync I/O Variant**

- **Name:** `dbench_16c_30s_sync`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -s -t 30 16
```

**8\. High-Concurrency Sync I/O (Journal Stress Test)**

- **Name:** `dbench_64c_30s_sync_stress`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -s -t 30 64
```

**9\. Strict Synchronous I/O Torture Test (O_SYNC)**

- **Name:** `dbench_16c_30s_osync`
    
- **Command:**
    

```
sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -S -t 30 16
```

* * *

### Mount Option Variations

**10\. Mount Option: Minimal Metadata Overhead (noatime)**

- **Name:** `dbench_64c_30s_noatime`
    
- **Command:**
    

```
sudo mount -o remount,noatime,nodiratime /mnt/ext4test && sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 64
```

**11\. Mount Option: Delayed Journaling (commit=60)**

- **Name:** `dbench_16c_30s_commit60`
    
- **Command:**
    

```
sudo mount -o remount,commit=60 /mnt/ext4test && sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 16
```

**12\. Full Data Journaling (Maximum Safety, Terrible Speed)**

- **Name:** `dbench_16c_30s_data_journal`
    
- **Command:**
    

```
sudo mount -o remount,data=journal /mnt/ext4test && sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 16
```

**13\. Asynchronous Writeback (Maximum Speed, High Risk)**

- **Name:** `dbench_16c_30s_data_writeback`
    
- **Command:**
    

```
sudo mount -o remount,data=writeback /mnt/ext4test && sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 16
```

* * *

### The Space-Pressure Track

> **Note:** Requires a 16GB Loop Device. Test #1 (Baseline) serves as the "0% Full" trace. The next two commands incrementally fill the drive to trace the performance degradation.

**14\. Space Pressure: 50% Capacity**

- **Name:** `dbench_16c_30s_50percent_full`
    
- **Command:**
    

```
sudo dd if=/dev/zero of=/mnt/ext4test/filler_50 bs=1M count=8000 && sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 16
```

**15\. Space Pressure: 95% Capacity**

- **Name:** `dbench_16c_30s_95percent_full`
    
- **Command:**
    

```
sudo dd if=/dev/zero of=/mnt/ext4test/filler_95 bs=1M count=7200 && sudo -g ext4_grp dbench -c /usr/share/dbench/client.txt -D /mnt/ext4test -t 30 16 && sudo rm /mnt/ext4test/filler_*
```

&nbsp;
