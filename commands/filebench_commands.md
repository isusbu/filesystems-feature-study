**1\. Micro-Block Random I/O (4K Page-Size Stress)**

- **Name:** `filebench_4k_randomwrite`
- **Command:**

```bash
sudo -g ext4_grp filebench -f /usr/share/filebench/workloads/randomwrite.f
```

> **Note:** Requires editing the `.f` file beforehand to set `iosize=4k` and `dir=/mnt/ext4test`.

**2\. Macro-Block Sequential I/O (1M Read-Ahead Stress)**

- **Name:** `filebench_1m_sequentialwrite`
- **Command:**

```bash
sudo -g ext4_grp filebench -f /usr/share/filebench/workloads/singlestreamwrite.f
```

> **Note:** Requires editing the `.f` file beforehand to set `iosize=1m` and `dir=/mnt/ext4test`.

**3\. Metadata-Heavy Test (Filebench)**

- **Name:** `filebench_varmail_metadata`
- **Command:**

```bash
sudo -g ext4_grp filebench -f /usr/share/filebench/workloads/varmail.f
```

> **Note:** Before running this, you'll need to open `/usr/share/filebench/workloads/varmail.f` in a text editor and change the line `set $dir=/tmp` to `set $dir=/mnt/ext4test` so it targets your loop device.

**4\. Fragmentation / Create-Delete Stress Test (Filebench)**

- **Name:** `filebench_fileserver_frag`
- **Command:**

```bash
sudo -g ext4_grp filebench -f /usr/share/filebench/workloads/fileserver.f
```
