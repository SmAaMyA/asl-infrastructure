#!/bin/bash

echo "Initializing Backup Storage and Disaster Recovery Server..."

# Update and install dependencies
apt update && apt upgrade -y
apt install -y nfs-kernel-server curl wget ufw

# Configure firewall
ufw allow ssh
ufw allow 2049 # NFS
ufw enable

# Create backup directories for ETCD and Velero
mkdir -p /mnt/backups/etcd
mkdir -p /mnt/backups/velero

# Configure NFS Exports
echo "/mnt/backups/etcd *(rw,sync,no_root_squash)" >>/etc/exports
echo "/mnt/backups/velero *(rw,sync,no_root_squash)" >>/etc/exports
exportfs -a
systemctl restart nfs-kernel-server

# (Optional) Mount S3-Compatible Storage for Velero Backups
# apt install -y s3fs
# echo "<access_key_id>:<secret_access_key>" > ~/.passwd-s3fs
# chmod 600 ~/.passwd-s3fs
# s3fs mybucket /mnt/backups/velero -o passwd_file=~/.passwd-s3fs

echo "Backup Storage Server setup complete with NFS exports. S3-compatible storage can be configured if needed."
