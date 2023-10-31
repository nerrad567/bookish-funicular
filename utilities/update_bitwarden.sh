#!/bin/bash
# -------------------------------------------------------------
# Title: Bitwarden Binary Symlink Update Script
# Description: This Bash script dynamically updates the symbolic link 
#              for the Bitwarden AppImage binary to always point to the latest version.
#              It is crucial for ensuring that Bitwarden runs the most recent version 
#              without manual intervention.
# Dependencies: ls, ln, head
# Author: https://github.com/nerrad567/bookish-funicular
# -------------------------------------------------------------

# Specify the directory where the Bitwarden binaries are located
BITWARDEN_DIR=""

# Get the latest Bitwarden binary file name
LATEST_BITWARDEN=$(ls -1t "$BITWARDEN_DIR"/Bitwarden*.AppImage | head -n 1)

#echo $LATEST_BITWARDEN
#echo $BITWARDEN_DIR/run/bitwarden
# Create/update the symlink
ln -sf "$LATEST_BITWARDEN" "$BITWARDEN_DIR/run/bitwarden"
