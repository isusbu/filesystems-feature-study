cat /proc/kallsyms | awk '$2 ~ /^[Tt]$/ && $3 ~ /^btrfs_/ { if(!seen[$3]++) print $3 }' > filesystems/btrfs/kprobes.txt

Number of probes: 1363 
