#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Title: WireGuard VPN Service Management Script
# Description: A concise script to manage the WireGuard VPN service. It checks the current 
#              status of the WireGuard service, stops it if running, restarts otherwise, 
#              and then provides the current status.
# Author: https://github.com/nerrad567/bookish-funicular
# Dependencies: systemctl, sudo, echo
# ----------------------------------------------------------------------------------------------

SERVICE_NAME="wg-quick@wg0.service"

# Check if service is running
if systemctl is-active --quiet $SERVICE_NAME; then
  echo "Service is running. Stopping it..."
  sudo systemctl stop $SERVICE_NAME
else
  echo "Service is not running. Restarting it..."
  sudo systemctl restart $SERVICE_NAME
fi

# Print current status of the service
echo "Current status of $SERVICE_NAME:"
systemctl status $SERVICE_NAME --no-pager
