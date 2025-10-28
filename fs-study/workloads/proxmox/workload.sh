#!/bin/bash
# ======================================================
# Proxmox Full Feature Test Script
# (Covers VM, LXC, network, storage, backup, API)
# ======================================================

set -euo pipefail

echo "=== [1/10] Environment Setup ==="

# Basic parameters
VM_ID=101
CT_ID=201
STORAGE="local-lvm"
ISO_STORAGE="local"
VM_NAME="test-vm"
CT_NAME="test-ct"
TEMPLATE="local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"

# Check required commands
for cmd in qm pct pvesh wget; do
  command -v $cmd >/dev/null 2>&1 || { echo "Missing: $cmd"; exit 1; }
done

echo "Updating Proxmox packages..."
apt update -y && apt full-upgrade -y

echo "Downloading ISOs and container templates..."
mkdir -p /var/lib/vz/template/iso /var/lib/vz/template/cache

# Ubuntu ISO for VM
if [ ! -f /var/lib/vz/template/iso/ubuntu-22.04-live-server-amd64.iso ]; then
  wget -q -O /var/lib/vz/template/iso/ubuntu-22.04-live-server-amd64.iso \
    https://releases.ubuntu.com/22.04/ubuntu-22.04-live-server-amd64.iso
fi

# Debian LXC template
if [ ! -f /var/lib/vz/template/cache/debian-12-standard_12.0-1_amd64.tar.zst ]; then
  pveam update >/dev/null
  pveam download local debian-12-standard_12.0-1_amd64.tar.zst
fi

# ------------------------------------------------------
echo "=== [2/10] Create and Configure VM ==="

if qm status $VM_ID >/dev/null 2>&1; then
  echo "VM $VM_ID already exists. Skipping creation."
else
  qm create $VM_ID --name $VM_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
  qm importdisk $VM_ID /var/lib/vz/template/iso/ubuntu-22.04-live-server-amd64.iso $STORAGE
  qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$VM_ID-disk-0
  qm set $VM_ID --ide2 $ISO_STORAGE:iso/ubuntu-22.04-live-server-amd64.iso,media=cdrom
  qm set $VM_ID --boot c --bootdisk scsi0
  qm set $VM_ID --serial0 socket --vga serial0
  echo "VM created successfully."
fi

echo "Starting VM to test basic run..."
qm start $VM_ID
sleep 20
qm stop $VM_ID

# ------------------------------------------------------
echo "=== [3/10] Create and Configure LXC ==="

if pct status $CT_ID >/dev/null 2>&1; then
  echo "Container $CT_ID already exists. Skipping creation."
else
  pct create $CT_ID $TEMPLATE \
    --hostname $CT_NAME \
    --storage $STORAGE \
    --rootfs $STORAGE:2 \
    --memory 1024 --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --password root
  echo "LXC container created successfully."
fi

pct start $CT_ID
sleep 10
pct exec $CT_ID -- apt update -y && apt install -y nginx
pct stop $CT_ID

# ------------------------------------------------------
echo "=== [4/10] Snapshot, Clone, and Rollback Tests ==="

qm snapshot $VM_ID snap1 --description "Initial snapshot"
qm rollback $VM_ID snap1
pct snapshot $CT_ID snap1
pct rollback $CT_ID snap1

# ------------------------------------------------------
echo "=== [5/10] Networking and Firewall Test ==="

echo "Enabling firewall globally and for VM..."
pvenode config set --firewall 1
qm set $VM_ID --firewall 1
echo "Adding test rule..."
echo "[OPTIONS]
enable: 1
log_level_in: info
log_level_out: info
[IPSET ipset1]
1.2.3.4
[RULES]
IN ACCEPT -source +ipset1
OUT DROP
" > /etc/pve/firewall/$VM_NAME.fw

# ------------------------------------------------------
echo "=== [6/10] Storage Test (Disk resize and I/O) ==="

qm resize $VM_ID scsi0 +1G
echo "Resized VM disk."
pct exec $CT_ID -- bash -c "apt install -y fio && fio --name=test --rw=randwrite --size=128M --numjobs=2 --runtime=20"

# ------------------------------------------------------
echo "=== [7/10] Backup and Restore Test ==="

echo "Creating backup..."
vzdump $VM_ID --mode stop --compress zstd --storage $STORAGE
BACKUP_FILE=$(ls -t /var/lib/vz/dump/vzdump-qemu-${VM_ID}-*.vma.zst | head -n1)
echo "Backup file created: $BACKUP_FILE"

echo "Restoring VM to new ID 102..."
qmrestore $BACKUP_FILE 102 --storage $STORAGE

# ------------------------------------------------------
echo "=== [8/10] API Access Test ==="

echo "Testing API query..."
pvesh get /nodes/$(hostname)/status | jq .

# ------------------------------------------------------
echo "=== [9/10] Monitoring Test ==="

echo "Installing node exporter..."
apt install -y prometheus-node-exporter || true
systemctl enable --now prometheus-node-exporter

echo "Testing basic performance metrics..."
pvesh get /nodes/$(hostname)/report

# ------------------------------------------------------
echo "=== [10/10] Continuous Load Loop (5 min) ==="

END=$((SECONDS+300))
while [ $SECONDS -lt $END ]; do
  qm start $VM_ID
  pct start $CT_ID
  sleep 10
  qm snapshot $VM_ID loop-snap --description "loop"
  qm stop $VM_ID
  pct stop $CT_ID
  qm rollback $VM_ID loop-snap || true
  sleep 10
done

echo "=== All Proxmox features tested successfully! ==="
