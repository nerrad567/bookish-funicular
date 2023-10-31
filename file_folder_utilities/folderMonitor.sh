#!/bin/bash
# ==============================================================================
# Directory Synchronization Script
# ==============================================================================
# Description:
#   This script continuously monitors a source directory for any changes (such as
#   file creation, deletion, modification, or moving) and synchronizes these
#   changes to a destination directory using rsync. It can be run in a dry-run
#   mode to only monitor changes without actual synchronization, and it can
#   reverse the source and destination directories based on command line options.
#
# Usage:
#   ./script_name.sh [--dry-run] [--delete] [--reverse]
#
# Options:
#   --dry-run:   Enable dry-run mode, showing changes without syncing
#   --delete:    Enable rsync's delete option to remove dest files not in src
#   --reverse:   Swap the source and destination directories
#
# Dependencies:
#   bash
#   inotify-tools: For monitoring file system changes
#   rsync: For performing file synchronization
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
# ==============================================================================


# Set default values for src and dest
src=""
dest=""

# Set default values for the options
monitorOnly=false
deleteOption=""
reverseOption=false

# Check command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --dry-run) monitorOnly=true ;;
    --delete) deleteOption="--delete" ;;
    --reverse) reverseOption=true ;;
    *) echo "Unknown parameter passed: $1" ;;
  esac
  shift
done

# Reverse the source and destination directories if necessary
if [ "$reverseOption" = true ]; then
  temp="$src"
  src="$dest"
  dest="$temp"
fi

# Define the rsync command
rsyncCmd="rsync -a $src $dest $deleteOption --exclude=*.git --exclude=*.swp"

# Watch for changes in the source directory and sync with the destination
inotifywait -m -r --exclude='\.git|\.swp' -e create,delete,modify,move "$src" |
  while read path action file; do
    echo -e  "\n$(date '+%d-%m-%Y %H:%M:%S')"

    echo -e "\033[33mDetected change: $action $file\033[0m"

    if [ "$monitorOnly" = true ]; then
      echo -e "\033[34mDry Run\033[0m"
      $rsyncCmd --dry-run
    else
      echo -e "\033[31mCommitting Changes\033[0m"
      echo -e "\033[35mUpdate Direction: [$src] >>> [$dest]\033[0m"
      $rsyncCmd
    fi
    wait
  done
  
