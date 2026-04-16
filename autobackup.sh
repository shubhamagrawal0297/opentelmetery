#!/bin/bash

# MySQL Database Information
DB_USER="shubham"
DB_PASSWORD="dfos@123"
DB_HOST="103.25.175.172"   # ❌ http hata diya (important)
BACKUP_DIR="/root/DB_backup"

# Create backup directory if not exists
mkdir -p $BACKUP_DIR

# Timestamp
TIMESTAMP=$(date +"%Y%m%d")

# Dump database
mysqldump -u $DB_USER -h $DB_HOST -p$DB_PASSWORD shubham > "$BACKUP_DIR/Dfos_backup_$TIMESTAMP.sql"

# Permission
chmod 600 "$BACKUP_DIR/Dfos_backup_$TIMESTAMP.sql"

# Zip file
zip -j "$BACKUP_DIR/Dfos_backup_$TIMESTAMP.zip" "$BACKUP_DIR/Dfos_backup_$TIMESTAMP.sql"

# Remove SQL file
rm "$BACKUP_DIR/Dfos_backup_$TIMESTAMP.sql"

# ✅ Delete files older than 3 days
find $BACKUP_DIR -name "Dfos_backup_*.zip" -type f -mtime +3 -exec rm -f {} \;

echo "Backup completed and old backups deleted (older than 3 days)"
