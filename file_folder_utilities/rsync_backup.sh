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
# - SOURCE_DIR:   The directory to be backed up.
# - BACKUP_ROOT:  The root directory where backups will be stored. Can be a local path or a remote path in the 
#                 format 'user@host:/path/to/directory'.
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

# Initialize default configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SSH_KEY=""
NUM_BACKUPS=15
PRESERVE_INTERVAL=5
COUNTER_FILE="$SCRIPT_DIR/.rsync_backup_counter"
SOURCE_DIR=""
BACKUP_ROOT=""
LOG_FILE="$SCRIPT_DIR/rsync_backup.log"
ERROR_LOG_FILE="$SCRIPT_DIR/rsync_backup_error.log"
IS_REMOTE=false
DATE=$(date +"%d%m%Y"_"%H%M%S")
BACKUP_DIR="$BACKUP_ROOT/$DATE"
HOST="${BACKUP_ROOT%%:*}"
PRESERVED_BACKUPS_DIR="$BACKUP_ROOT/preserved"

# Parse command line arguments
SOURCE_DIR="${1:-$SOURCE_DIR}"
BACKUP_ROOT="${2:-$BACKUP_ROOT}"
NUM_BACKUPS="${3:-$NUM_BACKUPS}"

# Check if remote & adjust paths
if [[ "$BACKUP_ROOT" == *":"* ]]; then
  IS_REMOTE=true
  LATEST_BACKUP_DIR="${BACKUP_ROOT#*:}/latest"
  SYM_TARGET="${BACKUP_ROOT#*:}/$DATE/*"
  BACKUP_ROOT_FOLDER="${BACKUP_ROOT#*:}"  
else
  LATEST_BACKUP_DIR="$BACKUP_ROOT/latest"
  SYM_TARGET="$BACKUP_ROOT/$DATE/*"
  BACKUP_ROOT_FOLDER=$BACKUP_ROOT
fi

# excludes relative to backup folder
EXCLUDE_LIST=(
  "docker-volumes/certbot/conf/accounts"
  "docker-volumes/certbot/conf/archive"
  "docker-volumes/certbot/conf/live"
  "docker-volumes/nginx-proxy/conf/nginx/ssl/default.key"
)

RSYNC_EXCLUDES=()
for item in "${EXCLUDE_LIST[@]}"; do
  RSYNC_EXCLUDES+=(--exclude="$item")
done


# Initialize or update the backup counter

if [ -f "$COUNTER_FILE" ]; then
  COUNTER=$(( $(<"$COUNTER_FILE") + 1 ))
else
  COUNTER=1
fi
echo " ℹ️    Backups until preservation snapshot: " $((PRESERVE_INTERVAL - COUNTER))
echo "$COUNTER" > "$COUNTER_FILE"

# Validate source directory
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory $SOURCE_DIR does not exist." >&2
  exit 1
fi


# Function to check and create directory
# check_and_create_dir "$BACKUP_ROOT" "$IS_REMOTE"
# check_and_create_dir "$PRESERVED_BACKUPS_DIR" "$IS_REMOTE"
# check_and_create_dir "$LATEST_BACKUP_DIR" "$IS_REMOTE"
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
# perform_rsync "$SOURCE_DIR" "$BACKUP_DIR" "$IS_REMOTE";
perform_rsync() {
  local source_dir=$1
  local backup_dir=$2
  local is_remote=$3

  if [ "$is_remote" = true ]; then
    rsync -e "ssh -i $SSH_KEY" -ah "${RSYNC_EXCLUDES[@]}" "$source_dir" "$backup_dir" 2>"$ERROR_LOG_FILE"
  else
    rsync -ah "${RSYNC_EXCLUDES[@]}" "$source_dir" "$backup_dir" 2>"$ERROR_LOG_FILE"
  fi
}


# Function to create a symbolic link
# create_symbolic_link "$SYM_TARGET" "$LATEST_BACKUP_DIR" "$IS_REMOTE"
create_symbolic_link() {
  local source_backup_dir=$1
  local latest_backup_dir=$2
  local is_remote=$3
  if [ "$is_remote" = true ]; then
    ssh -i "$SSH_KEY" "$HOST" "ln -sfn $source_backup_dir $latest_backup_dir" 2>/dev/null || { echo "Error: Unable to create remote symbolic link from $source_backup_dir to $latest_backup_dir on $HOST"; return 1; }
  else
    ln -sfn $source_backup_dir $latest_backup_dir 2>/dev/null || { echo "Error: Unable to create local symbolic link from $target_dir to $link_name"; return 1; }
  fi
}

# Function to create a preservation snapshot
# create_preservation_snapshot "$SOURCE_DIR" "$PRESERVED_BACKUPS_DIR"  "$IS_REMOTE"
create_preservation_snapshot() {
  local source_dir=$1
  local dest_dir=$2/$DATE
  local is_remote=$3
 
  if [ "$is_remote" = true ]; then
    echo "⏳   Creating preservation archive..."
    rsync -e "ssh -i $SSH_KEY" -ah "${RSYNC_EXCLUDES[@]}" "$source_dir" "$dest_dir" 2>"$ERROR_LOG_FILE"
  else
    rsync -ah "${RSYNC_EXCLUDES[@]}" "$source_dir" "$dest_dir" 2>"$ERROR_LOG_FILE"
  fi 


}


# Function to rotate backups, aka remove older backups than NUM_BACKUPS
# rotate_backups "$BACKUP_ROOT_FOLDER" "$NUM_BACKUPS"
rotate_backups() {
  local backup_root_folder=$1
  local num_backups=$2
  local is_remote=$3

  if [ "$is_remote" = true ]; then
    ssh -i "$SSH_KEY" "$HOST" "ls -t '$backup_root_folder' | grep -v preserved | sed -e '1,${num_backups}d' | xargs -I {} -r rm -rf -- '$backup_root_folder/{}'" 2>/dev/null || { echo "Error: Unable to manage backups in directory $backup_root_folder on $HOST"; exit 1; }

  else
    cd "$backup_root_folder" || { echo "Error: Unable to access backup directory $backup_root"; exit 1; }
    ls -t | grep -v preserved | sed -e "1,${num_backups}d" | xargs -d '\n' -r rm -rf --
  fi  

}

# Check if directories exist, and create if not.
echo "⏳   Checking necessary directories and creating if they do not exist..."
check_and_create_dir "$BACKUP_ROOT" "$IS_REMOTE"
check_and_create_dir "$PRESERVED_BACKUPS_DIR" "$IS_REMOTE"
check_and_create_dir "$BACKUP_ROOT/latest" "$IS_REMOTE"
echo "✅   Directory check and creation complete."

# Perform the backup
echo "⏳   Starting rsync backup..."
if perform_rsync "$SOURCE_DIR" "$BACKUP_DIR" "$IS_REMOTE"; then
  echo "✅    Rsync backup successful:  $DATE" | tee -a "$LOG_FILE"
else
  rsync_exit_status=$?
  if [ $rsync_exit_status -eq 23 ]; then
    echo "⚠️   Warning: Rsync encountered some files/directories that could not be transferred (e.g., due to permissions). Check $ERROR_LOG_FILE for details." >> "$LOG_FILE" >&2
  else
    echo "⚠️   Error: Rsync backup failed: $DATE. Check $ERROR_LOG_FILE for details." >> "$LOG_FILE" >&2
    echo "⚠️   Exiting...   ⚠️"
    exit 1
  fi
fi

echo "⏳   Updating latest backup symbolic link..."
if ! create_symbolic_link "$SYM_TARGET" "$LATEST_BACKUP_DIR" "$IS_REMOTE"; then
  echo "⚠️   Warning: Symbolic link creation failed. Check $ERROR_LOG_FILE for details." >> "$LOG_FILE" >&2
else
  echo "✅   Latest backup symbolic link updated successfully."
fi

# Create a preservation snapshot if needed
if [ "$COUNTER" -ge "$PRESERVE_INTERVAL" ]; then
  echo "⏳   Backup counter reached $PRESERVE_INTERVAL. Creating a preservation snapshot..."
  if create_preservation_snapshot "$SOURCE_DIR" "$PRESERVED_BACKUPS_DIR" "$IS_REMOTE"; then
    echo "✅   Preservation snapshot created successfully."
    echo 0 > "$COUNTER_FILE"
  else
    rsync_exit_status=$?
    if [ $rsync_exit_status -eq 23 ]; then
      echo "⚠️   Warning: Rsync encountered some files/directories that could not be transferred (e.g., due to permissions). Check $ERROR_LOG_FILE for details." >> "$LOG_FILE" >&2
      echo 0 > "$COUNTER_FILE"
    else
      echo "⚠️   Error: Rsync backup failed: $DATE. Check $ERROR_LOG_FILE for details." >> "$LOG_FILE" >&2
      echo "⚠️   Exiting...   ⚠️"  
    fi
  fi
fi

# Rotate old backups
echo "⏳   Rotating old backups. Keeping the last $NUM_BACKUPS backups..."
if rotate_backups "$BACKUP_ROOT_FOLDER" "$NUM_BACKUPS" "$IS_REMOTE"; then
  echo "✅   Backup rotation complete. Old backups beyond the last $NUM_BACKUPS have been deleted."
else
  echo "⚠️   Warning: Backup rotation failed. Check $ERROR_LOG_FILE for details."
fi