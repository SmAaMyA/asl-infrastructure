#!/bin/bash

# Configuration Variables
ETCD_ENDPOINT="https://127.0.0.1:2379" # ETCD endpoint
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
BACKUP_DIR="/mnt/backups/etcd" # Replace with your off-cluster storage path

# Create backup directory if not exists
mkdir -p $BACKUP_DIR

# Perform ETCD backup with timestamped snapshot
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SNAPSHOT="$BACKUP_DIR/etcd-snapshot-$TIMESTAMP.db"
etcdctl --endpoints=$ETCD_ENDPOINT \
    --cert=$ETCD_CERT \
    --key=$ETCD_KEY \
    --cacert=$ETCD_CACERT \
    snapshot save $SNAPSHOT

echo "ETCD backup completed: $SNAPSHOT"
