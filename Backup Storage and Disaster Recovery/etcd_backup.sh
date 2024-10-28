#!/bin/bash

# Configuration Variables
ETCD_ENDPOINTS="https://192.168.1.101:2379,https://192.168.1.102:2379,https://192.168.1.103:2379"
BACKUP_DIR="/mnt/backups/etcd"

# Perform ETCD backup on each endpoint
for endpoint in ${ETCD_ENDPOINTS//,/ }; do
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SNAPSHOT="$BACKUP_DIR/etcd-snapshot-$TIMESTAMP-$(echo $endpoint | cut -d'.' -f4).db"
    etcdctl --endpoints=$endpoint \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        snapshot save $SNAPSHOT
    echo "ETCD backup completed for endpoint $endpoint: $SNAPSHOT"
done
