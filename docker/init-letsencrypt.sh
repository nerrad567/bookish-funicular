#!/bin/bash

################################################################################
#                                                                              #
# Script Name: SSL Certificate Generator                                       #
#                                                                              #
# Description: This script is used to generate SSL certificates for the        #
#              specified domains using Let's Encrypt and Certbot.              #
#              We need to create selfsigned certficates first to allow         #
#              nginx to start                                                  #
#                                                                              #
#              The script performs the following operations:                   #
#              1. Checks if Docker Compose is installed.                       #
#              2. Checks if the specified data directory exists and is empty.  #
#              3. If the directory is not empty, it prompts the user to either #
#                 continue (which will delete all existing files in the        #
#                 directory) or exit the script.                               #
#              4. If the directory does not exist, it prompts the user to      #
#                 create it.                                                   #
#              5. Downloads the recommended TLS parameters if they are not     #
#                 already downloaded.                                          #
#              6. Creates dummy certificates for each domain.                  #
#              7. Starts Nginx.                                                #
#              8. Deletes the dummy certificates.                              #
#              9. Requests the actual Let's Encrypt certificates.              #
#              10. Reloads Nginx.                                              #
#                                                                              #
# Original Script Author: https://github.com/wmnnd/nginx-certbot               #
#                 Author: https://github.com/nerrad567/miniature-spoon         #
# Date: 24 August 2023                                                         #
# Version: 1.0                                                                 #
#                                                                              #
################################################################################

# Define the domains for which the certificates are to be generated
domains=("lolek.plumbing" "ackermanselfstorage.com")

# Define the RSA key size
rsa_key_size=4096

# Define the path where the data will be stored
data_path="/home/darren/docker-volumes/certbot"

# Define the email address for the certificate
email="" # Adding a valid address is strongly recommended

# Define the staging variable. Set to 1 for testing to avoid hitting request limits
staging=1

# Initialize the compose_command variable
compose_command=""

# Check if docker-compose command is available
if [ -x "$(command -v docker-compose)" ]; then
    compose_command="docker-compose"
# Check if docker and compose commands are available
elif { [ -x "$(command -v docker)" ] && [ -x "$(command -v compose)" ]; }; then
    compose_command="docker compose"
fi

# If compose_command is still empty, docker compose or docker-compose is not installed
if [ -z "$compose_command" ]; then
    echo 'Error: docker compose or docker-compose is not installed.' >&2
    exit 1
fi

# Check if certbot folder exists and contains data
if [ -d "$data_path" ]; then
    echo "Directory $data_path exists."

    # Check if directory is empty
    if [ "$(ls -A $data_path)" ]; then
        while true; do
            echo "Directory is not empty. Continuing will overwrite existing certificates. Do you wish to continue? (y/n)"
            read answer

            # If user chooses not to continue, exit the script
            if [ "$answer" = "n" ] || [ "$answer" = "N" ]; then
                echo "Exiting script."
                exit 1
            # If user chooses to continue, delete existing files and continue setup
            elif [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
                echo "Deleting existing files in the directory..."
                rm -rf $data_path/*
                echo "Files deleted. Continuing setup..."
                break
            else
                echo "Invalid choice. Please enter y or n."
            fi
        done
    fi
else
    while true; do
        echo "Directory $data_path does not exist. Do you want to create it? (y/n)"
        read answer

        # If user chooses not to create the directory, exit the script
        if [ "$answer" = "n" ] || [ "$answer" = "N" ]; then
            echo "Directory not created. Exiting script."
            exit 1
        # If user chooses to create the directory, create it and continue setup
        elif [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            mkdir -p $data_path
            echo "Directory created. Continuing setup..."
            break
        else
            echo "Invalid choice. Please enter y or n."
        fi
    done
fi

# If the recommended TLS parameters are not downloaded, download them
if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
    echo "### Downloading recommended TLS parameters ..."
    mkdir -p "$data_path/conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf >"$data_path/conf/options-ssl-nginx.conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem >"$data_path/conf/ssl-dhparams.pem"
    echo
fi

# Create dummy certificates for each domain
#for domain in $domains; do
for domain in "${domains[@]}"; do

    echo "### Creating dummy certificate for $domain ..."
    path="/etc/letsencrypt/live/$domain"
    mkdir -p "$data_path/conf/live/$domain"
    $compose_command run --rm --entrypoint "\
      openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
        -keyout '$path/privkey.pem' \
        -out '$path/fullchain.pem' \
        -subj '/CN=localhost'" certbot
    echo
done

# Start nginx
echo "### Starting nginx ..."
$compose_command up --force-recreate -d nginx
echo

# Delete dummy certificates for each domain
#for domain in $domains; do
for domain in "${domains[@]}"; do
    echo "### Deleting dummy certificate for $domain ..."
    $compose_command run --rm --entrypoint "\
      rm -Rf /etc/letsencrypt/live/$domain && \
      rm -Rf /etc/letsencrypt/archive/$domain && \
      rm -Rf /etc/letsencrypt/renewal/$domain.conf" certbot
    echo
done

# Request Let's Encrypt certificate for each domain
for domain in "${domains[@]}"; do
    echo "### Requesting Let's Encrypt certificate for $domain ..."

    # Select appropriate email arg
    case "$email" in
    "") email_arg="--register-unsafely-without-email" ;;
    *) email_arg="--email $email" ;;
    esac

    # Enable staging mode if needed
    if [ $staging != "0" ]; then staging_arg="--staging"; fi

    $compose_command run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
      $staging_arg \
      $email_arg \
      -d $domain \
      -d www.$domain \
      --rsa-key-size $rsa_key_size \
      --agree-tos \
      --force-renewal" certbot
    echo
done

# Reload nginx
echo "### Reloading nginx ..."
$compose_command exec nginx nginx -s reload
