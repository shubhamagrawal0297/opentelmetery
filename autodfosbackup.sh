#!/bin/bash

# ==============================
# DFOS Code Backup Script
# ==============================

BACKUP_DIR="/root/dfos_backup"
DFOS_CODE_DIR="/var/www/html/app"

# Create backup folder if not exists
mkdir -p "$BACKUP_DIR"

# Timestamp (date + time)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "Starting backup at $TIMESTAMP..."
# Create zip
cd "$DEST_DIR" || exit
zip -r "$BACKUP_DIR/Dfos_$TIMESTAMP.zip" "app"

# Delete backups older than 3 days
find "$BACKUP_DIR" -name "Dfos_*.zip" -type f -mtime +3 -exec rm -f {} \;

echo "Backup completed successfully."
echo "Old backups older than 3 days deleted."
