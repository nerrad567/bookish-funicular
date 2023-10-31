#!/bin/bash
#
# Simple Bash Script for Certbot Management
# Author: https://github.com/nerrad567/bookish-funicular
#
# This script facilitates the management and creation of SSL certificates 
# using Certbot inside a Docker container. It handles user inputs, manages 
# default values, and constructs the Certbot command dynamically based 
# on provided or default settings.
#
# Dependencies: Docker, Certbot, Bash
# Assumes running in a Unix-like environment with Bash installed.
#

# Set default values
DEFAULT_WEBROOT_PATH="/var/www/certbot"
DEFAULT_CONTAINER_NAME="certbot-certbot-1"
DEFAULT_AGREE_TOS="yes"
DEFAULT_NO_EFF_EMAIL="yes"
DEFAULT_DOMAINS=""
DEFAULT_EMAIL=""
DEFAULT_DRY_RUN=""

# Override defaults with environment variables if set
WEBROOT_PATH="${WEBROOT_PATH:-$DEFAULT_WEBROOT_PATH}"
CONTAINER_NAME="${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}"
AGREE_TOS="${AGREE_TOS:-$DEFAULT_AGREE_TOS}"
NO_EFF_EMAIL="${NO_EFF_EMAIL:-$DEFAULT_NO_EFF_EMAIL}"
DOMAINS="${DOMAINS:-$DEFAULT_DOMAINS}"
EMAIL="${EMAIL:-$DEFAULT_EMAIL}"
DRY_RUN="${DRY_RUN:-$DEFAULT_DRY_RUN}"

# Prompt for domains if not set
if [ -z "$DOMAINS" ]; then
  read -p "Enter the domains (separated by a space): " domains
else
  domains=$DOMAINS
fi

# Convert domains to Certbot format
domain_args=""
for domain in $domains; do
  domain_args="$domain_args -d $domain"
done

# Prompt for email if not set
if [ -z "$EMAIL" ]; then
  read -p "Enter your email address: " email
else
  email=$EMAIL
fi

# Ask for dry run if not set
if [ -z "$DRY_RUN" ]; then
  read -p "Do you want to do a dry run? (yes/no): " dry_run
else
  dry_run=$DRY_RUN
fi

# Build the Certbot command
cmd="docker exec -it $CONTAINER_NAME certbot certonly --webroot -w $WEBROOT_PATH $domain_args --email $email"

# Add flags based on user choices or defaults
[ "$AGREE_TOS" = "yes" ] && cmd="$cmd --agree-tos"
[ "$NO_EFF_EMAIL" = "yes" ] && cmd="$cmd --no-eff-email"
[ "$dry_run" = "yes" ] && cmd="$cmd --dry-run"

# Run the Certbot command
eval $cmd
