
#!/bin/bash
# Offsite backup script for sending etcd snapshots to AWS S3

BACKUP_DIR=/backups
LATEST_BACKUP=$(ls -t $BACKUP_DIR/etcd-* | head -1)
S3_BUCKET="s3://your-backup-bucket/etcd-backups/"

# Verify if backup exists
if [[ -f "$LATEST_BACKUP" ]]; then
    echo "Uploading $LATEST_BACKUP to S3..."
    aws s3 cp "$LATEST_BACKUP" "$S3_BUCKET"
    echo "Backup uploaded successfully to $S3_BUCKET"
else
    echo "No backup found to upload."
fi
