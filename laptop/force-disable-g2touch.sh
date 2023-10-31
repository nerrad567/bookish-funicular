#!/bin/bash

# ==============================================================================
# Script Name: toggle_device_state.sh
# Description: This script continuously monitors the state of a specific input device on a Linux system using xinput.
#              If the specified device is found and enabled, the script will automatically disable it. The script provides
#              real-time feedback on the device's state, and it can be run in a quiet mode where these notifications are
#              suppressed. The target device is identified by its name, and the script uses the xinput tool to interact
#              with the device. This script is especially useful for managing devices that may become active and interfere
#              with the normal operation of the system, providing a straightforward solution to temporarily disable them.
#              
# Author: https://github.com/nerrad567/bookish-funicular
# Usage: ./toggle_device_state.sh [--quiet]
# Dependencies: xinput (X Input extension), grep, cut
# Note: Make sure to give executable permissions to the script before running: chmod +x toggle_device_state.sh
# ==============================================================================

# Define the name of the device we're looking for
DEVICE_NAME="G2Touch Multi-Touch by G2TSP"

# Set the initial value of the quiet flag to false
QUIET=false

# Define some color codes for the output
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m" # No Color

# Parse command line arguments to check for the quiet flag
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)
      QUIET=true
      shift
      ;;
    *)
      echo "Usage: $0 [--quiet]"
      exit 1
      ;;
  esac
done

# Function to output a message if the quiet flag is not set
function output() {
  if ! $QUIET; then
    echo -e "${YELLOW}$1 [${GREEN}DEVICE_NAME=${DEVICE_NAME}${NC} ${GREEN}DEVICE_ID=${DEVICE_ID}${NC} ${GREEN}DEVICE_ENABLED=${DEVICE_ENABLED}${NC}]"
  fi
}

# Initialize the previous value of DEVICE_ENABLED to an empty string
PREVIOUS_DEVICE_ENABLED=""

while true; do
  # Get the ID of the device
  DEVICE_ID=$(xinput list | grep "$DEVICE_NAME" | grep -o "id=[0-9]*" | cut -d "=" -f 2)
  
  # If the device is found, check if it's enabled
  if [[ -n "$DEVICE_ID" ]]; then
    DEVICE_ENABLED=$(xinput list-props "$DEVICE_ID" | grep "Device Enabled" | grep -o "[01]$")
    
    # Output a message if the value of DEVICE_ENABLED has changed
    if [[ "$DEVICE_ENABLED" != "$PREVIOUS_DEVICE_ENABLED" ]]; then
      output "Device state: DEVICE_ENABLED=${DEVICE_ENABLED}"
      PREVIOUS_DEVICE_ENABLED="$DEVICE_ENABLED"
    fi
    
    # If the device is enabled, disable it and output to the console
    if [[ "$DEVICE_ENABLED" == "1" ]]; then
      xinput disable "$DEVICE_NAME"
      output "${RED}Disabled device${NC}"
    fi
  fi
  
  # Wait for a short period of time before checking again
  sleep 1
done
