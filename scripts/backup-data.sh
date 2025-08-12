#!/bin/bash
# Data backup script for keenOn-card-compose service

set -e

# Configuration
SERVICE_NAME="keenon-card-compose"
BACKUP_DIR="/data/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATA_DIR="/data/compose"
BACKUP_FILE="${BACKUP_DIR}/${SERVICE_NAME}_${TIMESTAMP}.tar.gz"
RETENTION_DAYS=7

# Ensure backup directory exists
mkdir -p ${BACKUP_DIR}

# Create data backup
echo "Creating backup of ${SERVICE_NAME} data..."

# Check if data directory exists and has content
if [ -d "${DATA_DIR}" ] && [ "$(ls -A ${DATA_DIR})" ]; then
  # Create tar archive of the data directory
  tar -czf ${BACKUP_FILE} -C $(dirname ${DATA_DIR}) $(basename ${DATA_DIR})

  # Check if backup was successful
  if [ $? -eq 0 ]; then
    echo "Backup created successfully: ${BACKUP_FILE}"

    # Clean up old backups
    echo "Cleaning up backups older than ${RETENTION_DAYS} days..."
    find ${BACKUP_DIR} -name "${SERVICE_NAME}_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

    # Log backup information
    echo "$(date): Backup created: ${BACKUP_FILE}" >> ${BACKUP_DIR}/backup.log

    # Create a symlink to the latest backup
    ln -sf ${BACKUP_FILE} ${BACKUP_DIR}/${SERVICE_NAME}_latest.tar.gz
  else
    echo "Backup failed!"
    echo "$(date): Backup failed" >> ${BACKUP_DIR}/backup.log
    exit 1
  fi
else
  echo "Data directory ${DATA_DIR} does not exist or is empty. Nothing to backup."
  echo "$(date): No data to backup" >> ${BACKUP_DIR}/backup.log
fi

# Optional: Upload to cloud storage
if command -v aws &> /dev/null && [ -n "${AWS_S3_BUCKET}" ]; then
  echo "Uploading backup to S3..."
  aws s3 cp ${BACKUP_FILE} s3://${AWS_S3_BUCKET}/${SERVICE_NAME}/

  if [ $? -eq 0 ]; then
    echo "Upload to S3 successful"
    echo "$(date): Backup uploaded to S3" >> ${BACKUP_DIR}/backup.log
  else
    echo "Upload to S3 failed"
    echo "$(date): S3 upload failed" >> ${BACKUP_DIR}/backup.log
  fi
fi

echo "Backup process completed."
