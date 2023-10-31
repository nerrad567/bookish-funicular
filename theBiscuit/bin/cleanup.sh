#!/bin/bash

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
