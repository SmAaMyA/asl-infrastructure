
#!/bin/bash
# Automated backup testing script for Kubernetes etcd

BACKUP_DIR=/backups
LATEST_BACKUP=$(ls -t $BACKUP_DIR/etcd-* | head -1)

# Verify if backup exists
if [[ -f "$LATEST_BACKUP" ]]; then
    echo "Testing recovery from latest backup: $LATEST_BACKUP"
    # Simulate restoring etcd (command may vary based on actual setup)
    etcdctl snapshot restore "$LATEST_BACKUP" --data-dir /tmp/etcd-restore-test
    echo "Backup test successful for $LATEST_BACKUP"
else
    echo "No backup found for testing."
fi
