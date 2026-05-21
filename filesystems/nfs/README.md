# NFS

## Options valid for all NFS versions

| # | Option | Default | Notes |
|---|---|:---:|---|
| 01 | `nfsvers=n` / `vers=n` | negotiated | Client tries v4 → v3 → v2; no fixed default |
| 02 | `soft` / `hard` | hard | `hard`: retries indefinitely on timeout (safer for data) |
| 03 | `timeo=n` | 600 (TCP) / adaptive (UDP) | Timeout in deciseconds before retry |
| 04 | `retrans=n` | 2 (TCP) / 3 (UDP) | Number of retries before further recovery |
| 05 | `rsize=n` | negotiated | Max bytes per READ request; negotiated if unset |
| 06 | `wsize=n` | negotiated | Max bytes per WRITE request; negotiated if unset |
| 07 | `ac` / `noac` | ac ✓ | Client caches file attributes; `noac` forces synchronous writes |
| 08 | `acregmin=n` | 3 s | Min time to cache regular file attributes |
| 09 | `acregmax=n` | 60 s | Max time to cache regular file attributes |
| 10 | `acdirmin=n` | 30 s | Min time to cache directory attributes |
| 11 | `acdirmax=n` | 60 s | Max time to cache directory attributes |
| 12 | `actimeo=n` | — | Sets acregmin/acregmax/acdirmin/acdirmax all to same value |
| 13 | `bg` / `fg` | fg ✓ | `fg`: mount failure exits with error; `bg`: retries in background |
| 14 | `retry=n` | 2 min (fg) / 10000 min (bg) | Minutes to retry mount before giving up |
| 15 | `sec=flavors` | negotiated | Security: `sys` / `krb5` / `krb5i` / `krb5p` / `none`; negotiated if unset |
| 16 | `lookupcache=mode` | all ✓ | Directory entry cache: `all` / `pos` / `none` |
| 17 | `fsc` / `nofsc` | nofsc | Local disk caching via FS-Cache; off by default |
| 18 | `rdirplus` / `nordirplus` | heuristic ✓ | Uses READDIRPLUS on NFSv3/v4; client decides automatically |
| 19 | `sharecache` / `nosharecache` | sharecache ✓ | Shared data/attr cache across mounts of the same export |
| 20 | `resvport` / `noresvport` | resvport ✓ | Uses privileged source port (<1024) |
| 21 | `nconnect=n` | 1 | Number of TCP connections to server; max 16 (kernel 5.3+) |
| 22 | `xprtsec=policy` | none (kernel-dependent) | Transport layer security: `none` / `tls` / `mtls` |
| 23 | `noalignwrite` | off (alignwrite on ✓) | Disables page-boundary alignment of buffered writes |
| 24 | `intr` / `nointr` | — | **Ignored** since kernel 2.6.25; kept for compatibility only |
| 25 | `sloppy` | off | Ignores unrecognized mount options (alias for `mount.nfs -s`) |
| 26 | `local_lock=mechanism` | none | Local-only locking: `none` / `flock` / `posix` / `all` |

## Options for NFS v2 and v3 only

| # | Option | Default | Notes |
|---|---|:---:|---|
| 27 | `proto=netid` | negotiated | Transport: `tcp` / `udp` / `tcp6` / `udp6` / `rdma` |
| 28 | `udp` | — | Alias for `proto=udp` |
| 29 | `tcp` | — | Alias for `proto=tcp` |
| 30 | `rdma` | — | Alias for `proto=rdma` |
| 31 | `port=n` | advertised by rpcbind | NFS service port; 0 = use rpcbind advertisement |
| 32 | `mountport=n` | advertised by rpcbind | mountd port; 0 = use rpcbind advertisement |
| 33 | `mountproto=netid` | negotiated | Transport for mountd requests only |
| 34 | `mounthost=name` | same as NFS server | Hostname running mountd |
| 35 | `mountvers=n` | version-appropriate | RPC version for mountd contact |
| 36 | `namlen=n` | negotiated | Max pathname component length; usually 255 |
| 37 | `lock` / `nolock` | lock ✓ | NLM sideband locking; `nolock` for servers without NLM |
| 38 | `cto` / `nocto` | cto ✓ | Close-to-open cache coherence semantics |
| 39 | `acl` / `noacl` | negotiated ✓ | NFSACL sideband protocol (Solaris-compat); negotiated if unset |

## Options for NFS v4 only

| # | Option | Default | Notes |
|---|---|:---:|---|
| 40 | `proto=netid` | tcp | Transport: `tcp` / `tcp6` / `rdma`; UDP not supported |
| 41 | `port=n` | 2049 | Standard NFS v4 port |
| 42 | `clientaddr=%s` | autodetected | IPv4/IPv6 address for NFSv4 callback; auto-detected if unset |
| 43 | `migration` / `nomigration` | nomigration ✓ | TSM-compatible client ID string for transparent state migration |

Reference: [https://man7.org/linux/man-pages/man5/nfs.5.html](https://man7.org/linux/man-pages/man5/nfs.5.html)

## NFS mount option requirements

### Options valid for all NFS versions

| # | Option | Default | SQLite | Redis | AIStore |
|---|---|:---:|:---:|:---:|:---:|
| 01 | `nfsvers=n` / `vers=n` | negotiated | — | — | — |
| 02 | `soft` / `hard` | hard | ✓ | ✓ | ✓ |
| 03 | `timeo=n` | 600 (TCP) | ✓ | ✓ | ✓ |
| 04 | `retrans=n` | 2 (TCP) | ✓ | ✓ | ✓ |
| 05 | `rsize=n` | negotiated | — | — | ✓ |
| 06 | `wsize=n` | negotiated | — | ✓ | ✓ |
| 07 | `ac` / `noac` | ac | ✓ | ✓ | ✓ |
| 08 | `acregmin=n` | 3 s | — | — | — |
| 09 | `acregmax=n` | 60 s | — | — | — |
| 10 | `acdirmin=n` | 30 s | — | — | — |
| 11 | `acdirmax=n` | 60 s | — | — | — |
| 12 | `actimeo=n` | — | — | — | — |
| 13 | `bg` / `fg` | fg | — | — | — |
| 14 | `retry=n` | 2 min (fg) | — | — | — |
| 15 | `sec=flavors` | negotiated | — | — | — |
| 16 | `lookupcache=mode` | all | — | — | — |
| 17 | `fsc` / `nofsc` | nofsc | — | — | — |
| 18 | `rdirplus` / `nordirplus` | heuristic | — | — | ✓ |
| 19 | `sharecache` / `nosharecache` | sharecache | — | — | — |
| 20 | `resvport` / `noresvport` | resvport | — | — | — |
| 21 | `nconnect=n` | 1 | — | — | ✓ |
| 22 | `xprtsec=policy` | none | — | — | — |
| 23 | `noalignwrite` | off | — | — | — |
| 24 | `intr` / `nointr` | — | — | — | — |
| 25 | `sloppy` | off | — | — | — |
| 26 | `local_lock=mechanism` | none | — | — | — |

### Options for NFS v2 and v3 only

| # | Option | Default | SQLite | Redis | AIStore |
|---|---|:---:|:---:|:---:|:---:|
| 27 | `proto=netid` | negotiated | — | — | — |
| 28 | `udp` | — | — | — | — |
| 29 | `tcp` | — | — | — | — |
| 30 | `rdma` | — | — | — | — |
| 31 | `port=n` | rpcbind | — | — | — |
| 32 | `mountport=n` | rpcbind | — | — | — |
| 33 | `mountproto=netid` | negotiated | — | — | — |
| 34 | `mounthost=name` | server host | — | — | — |
| 35 | `mountvers=n` | negotiated | — | — | — |
| 36 | `namlen=n` | negotiated | — | — | — |
| 37 | `lock` / `nolock` | lock | ✓ | — | — |
| 38 | `cto` / `nocto` | cto | ✓ | — | — |
| 39 | `acl` / `noacl` | negotiated | — | — | — |

### Options for NFS v4 only

| # | Option | Default | SQLite | Redis | AIStore |
|---|---|:---:|:---:|:---:|:---:|
| 40 | `proto=netid` | tcp | — | — | — |
| 41 | `port=n` | 2049 | — | — | — |
| 42 | `clientaddr=%s` | autodetected | — | — | — |
| 43 | `migration` / `nomigration` | nomigration | — | — | — |

### Summary

| | SQLite | Redis | AIStore |
|---|:---:|:---:|:---:|
| **Minimum options required** | **6** | **5** | **8** |

## Drivers

Setup a target disk for workloads test (NFS).

## Setup NFS server (once)

```bash
# install tools if needed
sudo apt-get install -y nfs-kernel-server nfs-common

# create a loop device for NFS server
sudo dd if=/dev/zero of=/mnt/nfs.img bs=1M count=4096
sudo mkfs.ext4 /mnt/nfs.img
sudo mkdir -p /srv/nfstest
sudo mount -o loop /mnt/nfs.img /srv/nfstest

# make a server-side export directory
sudo mkdir -p /srv/nfstest
sudo chown -R "$USER":"$USER" /srv/nfstest

# export only to localhost for local tracing tests
echo '/srv/nfstest 127.0.0.1(rw,sync,no_subtree_check,no_root_squash)' | sudo tee /etc/exports.d/nfstest.exports >/dev/null
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
```

## Setup mount points

```bash
# make a client mount point
sudo mkdir -p /mnt/nfstest

# mount NFS export
sudo mount -t nfs -o nfsvers=4,softreval,timeo=600,retrans=2,rsize=1048576,wsize=1048576,ac,acregmin=3,acregmax=60,acdirmin=30,acdirmax=60,bg,nconnect=16,rdirplus,retry=2,sec=sys,sharecache,resvport,lookupcache=all,fsc,xprtsec=none,noalignwrite 127.0.0.1:/srv/nfstest /mnt/nfstest

# check
mount | grep nfs
# 127.0.0.1:/srv/nfstest on /mnt/nfstest type nfs4 (rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=127.0.0.1,local_lock=none,addr=127.0.0.1)
```

```bash
# cleanup
cd ~
sudo umount /mnt/nfstest
sudo rm -rf /mnt/nfstest

# server cleanup
sudo rm -f /etc/exports.d/nfstest.exports
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

sudo rm -rf /srv/nfstest
```
