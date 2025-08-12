#!/bin/bash
# Data restore script for keenOn-card-compose service

set -e

# Configuration
SERVICE_NAME="keenon-card-compose"
BACKUP_DIR="/data/backups"
DATA_DIR="/data/compose"
LATEST_BACKUP="${BACKUP_DIR}/${SERVICE_NAME}_latest.tar.gz"

# Function to display usage information
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -f, --file BACKUP_FILE  Specify a backup file to restore from"
  echo "  -l, --latest            Restore from the latest backup (default)"
  echo "  -h, --help              Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --latest             Restore from the latest backup"
  echo "  $0 -f /path/to/backup.tar.gz  Restore from a specific backup file"
}

# Parse command line arguments
BACKUP_FILE=""
USE_LATEST=true

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--file)
      BACKUP_FILE="$2"
      USE_LATEST=false
      shift 2
      ;;
    -l|--latest)
      USE_LATEST=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Determine which backup file to use
if [ "$USE_LATEST" = true ]; then
  if [ -L "$LATEST_BACKUP" ]; then
    BACKUP_FILE=$(readlink -f "$LATEST_BACKUP")
    echo "Using latest backup: $BACKUP_FILE"
  else
    echo "Error: Latest backup symlink not found at $LATEST_BACKUP"
    exit 1
  fi
else
  if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Specified backup file not found: $BACKUP_FILE"
    exit 1
  fi
fi

# Confirm restore operation
echo "WARNING: This will overwrite the current data in $DATA_DIR with data from $BACKUP_FILE"
read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Restore cancelled."
  exit 0
fi

# Create a backup of current data if it exists
if [ -d "$DATA_DIR" ] && [ "$(ls -A $DATA_DIR)" ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  PRE_RESTORE_BACKUP="${BACKUP_DIR}/${SERVICE_NAME}_pre_restore_${TIMESTAMP}.tar.gz"
  echo "Creating backup of current data before restore..."
  tar -czf "$PRE_RESTORE_BACKUP" -C $(dirname "$DATA_DIR") $(basename "$DATA_DIR")
  echo "Current data backed up to: $PRE_RESTORE_BACKUP"
fi

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Restore from backup
echo "Restoring data from $BACKUP_FILE..."
tar -xzf "$BACKUP_FILE" -C /data

# Check if restore was successful
if [ $? -eq 0 ]; then
  echo "Restore completed successfully!"
  echo "$(date): Restore from $BACKUP_FILE completed successfully" >> "${BACKUP_DIR}/backup.log"
else
  echo "Restore failed!"
  echo "$(date): Restore from $BACKUP_FILE failed" >> "${BACKUP_DIR}/backup.log"
  exit 1
fi

echo "Restore process completed."
