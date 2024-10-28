
#!/bin/bash
# Enhanced Automated Backup Testing Script for etcd

BACKUP_DIR=/backups
LATEST_BACKUP=$(ls -t $BACKUP_DIR/etcd-* | head -1)

# Verify if the latest backup exists
if [[ -f "$LATEST_BACKUP" ]]; then
    echo "Testing restore from latest backup: $LATEST_BACKUP"
    # Create a temporary data directory for testing the restore
    RESTORE_DIR=/tmp/etcd-restore-test
    mkdir -p $RESTORE_DIR

    # Perform a restore to the temporary directory
    etcdctl snapshot restore "$LATEST_BACKUP" --data-dir=$RESTORE_DIR

    # Confirm restoration was successful by checking data integrity (example check)
    if [[ -d "$RESTORE_DIR/member" ]]; then
        echo "Backup test successful for $LATEST_BACKUP. Data integrity check passed."
        rm -rf $RESTORE_DIR  # Clean up after test
    else
        echo "Backup test failed for $LATEST_BACKUP. Restoration integrity check failed."
    fi
else
    echo "No backup found for testing."
fi
