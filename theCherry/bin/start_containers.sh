#!/bin/bash
#
# Docker Network and Container Management Script
#
# A comprehensive Bash script designed to facilitate the management of Docker networks and containers. 
# It ensures the script is executed with root privileges, checks for the existence of a specified Docker 
# network, and iteratively deploys Docker containers from defined Docker Compose files.
#
# Key Features:
# - Root Privilege Verification: Ensures the script is executed with the necessary permissions.
# - Docker Network Management: Checks for the existence of the 'websites' network, creating it if absent.
# - Iterative Container Deployment: Utilizes an array of paths to Docker Compose files, deploying containers 
#   if they are not already running.
#
# Usage:
# Execute this script with sudo to ensure proper functioning. The paths in the array should be updated to 
# reflect the locations of your Docker Compose files.
#
# Dependencies:
# - Bash
# - Docker: Ensure Docker is installed and operational on your system.
# - Docker Compose: Required for deploying containers using Docker Compose files.
#
# Author: https://github.com/nerrad567/bookish-funicular
#
# Ensure to replace the placeholders in the 'paths' array with the actual paths to your Docker Compose files. 
# This script is vital for maintaining an organized Docker environment and ensures seamless container deployment.
#

# Check if script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# Check if the network already exists, if not create it
if [ -z "$(docker network ls | grep websites)" ]
then
  echo "Creating Docker network 'websites'"
  docker network create websites
else
  echo "Docker network 'websites' already exists"
fi

# Define an array with the paths to your docker-compose files
declare -a paths=(
"...."
"...."
"...docker-compose/nginx-proxy"
"..."
)

# Loop over the array and run docker compose up -d in each directory
for path in "${paths[@]}"
do
  # Extract the service name from the path
  service_name=$(basename $path)

  # Check if the service is already running
  if [ -z "$(docker ps --filter name=$service_name --format '{{.Names}}')" ]
  then
    echo "Starting Docker containers in $path"
    cd $path
    docker compose up -d
  else
    echo "Docker containers in $path are already running"
  fi
done 

echo "All Docker containers started"
