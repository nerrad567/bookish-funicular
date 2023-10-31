#!/bin/bash
#
# Docker Cleanup Script
# 
# This Bash script is designed to streamline the process of stopping all running Docker
# containers and removing unused Docker data. Its functionalities are crucial for maintaining
# a clean and efficient Docker environment, especially in systems where Docker containers
# are frequently created and removed.
#
# Usage:
# Run the script with sudo privileges to ensure proper functioning. An optional '-y' flag
# can be provided to automatically confirm the removal of unused Docker data.
#
# Features:
# - Checks and ensures script is run as root for necessary permissions.
# - Optionally automates confirmation for data removal with '-y' flag.
# - Stops all running Docker containers.
# - Cleans up all unused Docker data, including volumes, networks, and images.
#
# Author: https://github.com/nerrad567/bookish-funicular
#
# Dependencies:
# - Bash
# - Docker: Ensure Docker is installed and running on your system.
#
# It is recommended to thoroughly understand the Docker cleanup commands used in this
# script, as they will remove all unused data, which may include volumes, networks, and
# images that are not associated with running containers.
#



# Check if script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Check if -y flag is provided
if [[ $1 == "-y" ]]; then
    AUTO_CONFIRM='y'
else
    AUTO_CONFIRM=''
fi

echo "Checking for running Docker containers..."

# Check if there are any running containers
if [ "$(docker ps -q)" != "" ]; then
    echo "Stopping running Docker containers..."
    # Stop all running containers
    docker stop $(docker ps -q)
else
    echo "No Docker containers are currently running."
fi

echo "Removing unused Docker data..."

# Remove all unused data
if [[ $AUTO_CONFIRM == 'y' ]]; then
    echo 'y' | docker system prune -a --volumes
else
    docker system prune -a --volumes
fi

echo "Docker cleanup completed."
