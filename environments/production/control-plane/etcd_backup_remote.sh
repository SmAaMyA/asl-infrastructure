
#!/bin/bash

# Automate etcd backup and store offsite
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db

# Remote storage command example for S3
aws s3 cp /backup/etcd-*.db s3://your-backup-bucket/etcd-backups/
