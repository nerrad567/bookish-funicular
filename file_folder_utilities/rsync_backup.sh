#!/bin/bash
# ====================================================================================================================
# Title: Rsync Backup Script
# Description: This script performs backups of a specified directory using rsync, managing local or remote backups,
# backup rotation, and preservation of specific backups. 
#
# Usage: 
# ./backup_script.sh [SOURCE_DIR] [BACKUP_ROOT] [NUM_BACKUPS]
#
# Arguments:
# - SOURCE_DIR:   The directory to be backed up. Defaults to '/home/darren/test' if not provided.
# - BACKUP_ROOT:  The root directory where backups will be stored. Can be a local path or a remote path in the 
#                 format 'user@host:/path/to/directory'. Defaults to '/home/darren/bkup' if not provided.
# - NUM_BACKUPS:  The number of backups to retain. Older backups beyond this limit will be rotated (deleted).
#                 Defaults to 5 if not provided.
#
# Dependencies:
# - rsync:        Required for performing the backups.
# - ssh:          Required if performing backups to a remote location.
# - mkdir, ls, grep, sed, xargs: Required for directory management and backup rotation.
#
# Configuration:
# - SSH_KEY:              The private key used for SSH authentication when performing remote backups. 
#                         Defaults to '~/.ssh/id_rsa'.
# - PRESERVE_INTERVAL:    The number of backups after which a preservation snapshot is created.
#                         Defaults to 10.
# - COUNTER_FILE:         The file used to store the backup counter, used for preservation intervals.
#                         No default; must be set explicitly in the script.
# - PRESERVED_BACKUPS_DIR: The directory where preservation snapshots are stored. 
#                          Defaults to '$BACKUP_ROOT/preserved'.
# - LOG_FILE:             The file where standard log messages are stored.
#                         Defaults to '/var/log/rsync_backup.log'.
# - ERROR_LOG_FILE:       The file where error log messages are stored.
#                         Defaults to '/var/log/rsync_backup_error.log'.
# - IS_REMOTE:            Boolean value indicating whether the backup is to a remote location. 
#                         Automatically determined based on the format of BACKUP_ROOT.
#
# Functions:
# - check_and_create_dir: Checks and creates the specified directory, either locally or remotely.
# - perform_rsync:        Performs the rsync operation to backup the source directory to the destination.
# - rotate_backups:       Rotates (deletes) backups older than the specified retention limit.
# - create_preservation_snapshot: Creates a preservation snapshot of the specified backup.
#
# Notes:
# - Ensure that the SSH key has the correct permissions (typically 600) and the path is correctly set.
# - Ensure that all dependencies are installed and accessible in the system's PATH.
# - The script is designed to be run manually or via a scheduled task (e.g., cron).
#
# Author: https://github.com/nerrad567/bookish-funicular
#
# ==========================================================================================================


# Function to check and create directory
check_and_create_dir() {
  local dir=$1
  local is_remote=$2
  
  if [ "$is_remote" = true ]; then
    local host="${dir%%:*}"
    local path="${dir#*:}"
    ssh -i "$SSH_KEY" "$host" "mkdir -p '$path'" 2>/dev/null || { echo "Error: Unable to create remote directory $path on $host"; exit 1; }
  else
    mkdir -p "$dir" 2>/dev/null || { echo "Error: Unable to create local directory $dir"; exit 1; }
  fi
}

# Function to perform rsync operation
perform_rsync() {
  local source_dir=$1
  local dest_dir=$2
  local is_remote=$3
  
  if [ "$is_remote" = true ]; then
    rsync -e "ssh -i $SSH_KEY" -ah --delete --link-dest="$BACKUP_ROOT/latest" "$source_dir" "$dest_dir" 2>"$ERROR_LOG_FILE"
  else
    rsync -ah --delete --link-dest="$BACKUP_ROOT/latest" "$source_dir" "$dest_dir" 2>"$ERROR_LOG_FILE"
  fi
}

# Function to rotate backups, aka remove older backups than NUM_BACKUPS
rotate_backups() {
  local backup_root=$1
  local num_backups=$2
  
  cd "$backup_root" || { echo "Error: Unable to access backup directory $backup_root"; exit 1; }
  ls -t | grep -v preserved | sed -e "1,${num_backups}d" | xargs -d '\n' -r rm -rf --
}

# Function to create a preservation snapshot
create_preservation_snapshot() {
  local source_dir=$1
  local dest_dir=$2
  
  rsync -ah "$source_dir/" "$dest_dir" || { echo "Error: Preservation snapshot failed"; exit 1; }
  echo "Preservation snapshot created: $dest_dir"
}

# Initialize default configuration
SSH_KEY="~/.ssh/id_rsa"
NUM_BACKUPS=5
PRESERVE_INTERVAL=10
COUNTER_FILE=".rsync_backup_counter"
SOURCE_DIR="/home/darren/test"
BACKUP_ROOT="/home/darren/bkup"
PRESERVED_BACKUPS_DIR="$BACKUP_ROOT/preserved"
LOG_FILE="/var/log/rsync_backup.log"
ERROR_LOG_FILE="/var/log/rsync_backup_error.log"
IS_REMOTE=false

# Parse command line arguments
SOURCE_DIR="${1:-$SOURCE_DIR}"
BACKUP_ROOT="${2:-$BACKUP_ROOT}"
NUM_BACKUPS="${3:-$NUM_BACKUPS}"

# Check if remote
if [[ "$BACKUP_ROOT" == *":"* ]]; then
  IS_REMOTE=true
fi

# Check if directorys exist, and create if it not.
check_and_create_dir "$BACKUP_ROOT" "$IS_REMOTE"
check_and_create_dir "$PRESERVED_BACKUPS_DIR" "$IS_REMOTE"
check_and_create_dir "$BACKUP_ROOT/latest" "$IS_REMOTE"

# Validate source directory
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory $SOURCE_DIR does not exist." >&2
  exit 1
fi

# Initialize or update the backup counter
if [ -f "$COUNTER_FILE" ]; then
  COUNTER=$(( $(<"$COUNTER_FILE") + 1 ))
else
  COUNTER=1
fi
echo "$COUNTER" > "$COUNTER_FILE"

# Perform the backup
DATE=$(date +"%Y%m%d%H%M%S")
BACKUP_DIR="$BACKUP_ROOT/$DATE"

if perform_rsync "$SOURCE_DIR" "$BACKUP_DIR" "$IS_REMOTE"; then
  echo "Rsync backup successful: $DATE" >> "$LOG_FILE"
  ln -sfn "$DATE" "$BACKUP_ROOT/latest"
else
  echo "Rsync backup failed: $DATE. See $ERROR_LOG_FILE for details." >> "$LOG_FILE" >&2
  exit 1
fi

# Create a preservation snapshot if needed
if [ "$COUNTER" -ge "$PRESERVE_INTERVAL" ]; then
  PRESERVED_BACKUP_DIR="$PRESERVED_BACKUPS_DIR/$DATE"
  create_preservation_snapshot "$BACKUP_DIR" "$PRESERVED_BACKUP_DIR"
  echo 0 > "$COUNTER_FILE"
fi

# Rotate old backups
rotate_backups "$BACKUP_ROOT" "$NUM_BACKUPS"


