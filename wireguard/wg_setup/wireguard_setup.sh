#!/bin/bash

# ----------------------------------------------------------------------------------------
# Title: WireGuard VPN Server and Client Configuration Script
# Description: This script facilitates the configuration of a WireGuard VPN server, along
#              with the generation, management, and QR code display of client configurations.
#              It ensures a streamlined process for setting up and maintaining secure
#              VPN connections.
# Author: https://github.com/nerrad567/bookish-funicular
# Dependencies: wg, qrencode, mkdir, rm, echo, sed, read, ls, basename, cat, grep, sort
# ----------------------------------------------------------------------------------------


# Variables
SERVER_DIR="$(dirname "$(readlink -f "$0")")/server"
CLIENT_DIR="$(dirname "$(readlink -f "$0")")/clients"
DNS="1.1.1.1"
MTU="1420"
ENDPOINT="n.n.n.n:51820"
IP_SPACE="10.0.0.0/24"
SERVER_ADDRESS="10.0.0.1/24"

# Create initial folders
create_structure() {
    # Get the directory of the script
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

    # Create the directories
    mkdir -p "$SCRIPT_DIR/server/keys"
    mkdir -p "$SCRIPT_DIR/server/configurations"
    mkdir -p "$SCRIPT_DIR/clients"

    echo "Base structure created"
}

# Function to create server configuration including generation of new private and public keys and iptables config
create_server() {
    # Check if wg0.conf already exists
    if [[ -f $SERVER_DIR/configurations/wg0.conf ]]; then
        echo -e "Error wg0.conf already exists. For a fresh start run this script with the flag -d \\n Exiting..."
        exit 1
    fi

    mkdir -p $SERVER_DIR/keys $SERVER_DIR/configurations
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
    echo "$SERVER_PRIVATE_KEY" >$SERVER_DIR/keys/server_private_key
    echo "$SERVER_PUBLIC_KEY" >$SERVER_DIR/keys/server_public_key
    echo "[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_ADDRESS
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE" >$SERVER_DIR/configurations/wg0.conf
echo "Server configuration and keys created"
}

# Function to create client configurations
create_clients() {
    # Find the highest existing client number
    EXISTING_CLIENT_COUNT=$(ls $CLIENT_DIR | grep -o '[0-9]\+' | sort -n | tail -1)

    # If no existing clients were found, start from 1
    if [[ -z $EXISTING_CLIENT_COUNT ]]; then
        EXISTING_CLIENT_COUNT=0
    fi

    read -p "Enter the number of clients to create: " CLIENT_COUNT
    for ((i = 1; i <= CLIENT_COUNT; i++)); do
        CLIENT_NUM=$((EXISTING_CLIENT_COUNT + i))
        CLIENT_PRIVATE_KEY=$(wg genkey)
        CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
        CLIENT_ADDRESS="10.0.0.$((CLIENT_NUM + 1))/24"
        mkdir -p $CLIENT_DIR/client$CLIENT_NUM/keys $CLIENT_DIR/client$CLIENT_NUM/configurations
        echo "$CLIENT_PRIVATE_KEY" >$CLIENT_DIR/client$CLIENT_NUM/keys/client_private_key
        echo "$CLIENT_PUBLIC_KEY" >$CLIENT_DIR/client$CLIENT_NUM/keys/client_public_key
        echo "[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_ADDRESS
DNS = $DNS
MTU = $MTU

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $ENDPOINT
AllowedIPs = 0.0.0.0/0, ::/0" >$CLIENT_DIR/client$CLIENT_NUM/configurations/wg0.conf
        qrencode -o $CLIENT_DIR/client$CLIENT_NUM/client$CLIENT_NUM.png <$CLIENT_DIR/client$CLIENT_NUM/configurations/wg0.conf
    done

    echo "Client configurations and keys created/updated"
}


# Function to update server configuration with clients
update_server() {
    # Remove the  everything below the [Peer] section from the server configuration
    sed -i '/\[Peer\]/,$d' $SERVER_DIR/configurations/wg0.conf

    # Loop through each client directory
    for CLIENT_DIR in $(ls -d $CLIENT_DIR/client*/); do
        # Extract the client number from the directory name
        CLIENT_NUM=$(basename $CLIENT_DIR | grep -o '[0-9]\+')

        # Read the client's public key
        CLIENT_PUBLIC_KEY=$(cat $CLIENT_DIR/keys/client_public_key)

        # Define the client's allowed IPs
        CLIENT_ALLOWED_IPS="10.0.0.$((CLIENT_NUM + 1))/32"

        # Append the client's information to the server configuration
        echo -e "[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_ALLOWED_IPS
" >> $SERVER_DIR/configurations/wg0.conf
    done

    echo "Server settings updated"
}

# Has this script already been run, if so lets update, if not let create server and structure too
initial_run() {
    # Check for the existence of the hidden initial run file
    if [ -f .initial_run ]; then
        create_clients
        update_server
    elif [ ! -f .initial_run ]; then
        check_and_install_packages
        create_structure
        create_server
        create_clients
        update_server
        touch .initial_run
    else
        # perform error handling
        echo "An error occurred."
    fi

}
fresh_start() {
    # Display warning notice
    echo -e "WARNING: EVERYTHING in the directory this script is executed from will be deleted except for the script itself. This includes all server and client configurations. 
Meaning existing clients will no longer be able to connect to the wireguard service"
    echo "To proceed, type the following phrase: DELETE EVERYTHING"

    # Read user input
    read user_input

    # Check if the user input is correct
    if [ "$user_input" = "DELETE EVERYTHING" ]; then
        # Get the script's own name
        script_name=$(basename "$0")

        # Loop over all files and directories in the current directory
        for file in * .[^.]* ..?*; do
            # If the file/directory is not the script itself, delete it
            if [ "$file" != "$script_name" ]; then
                rm -rf "$file"
            fi
        done

        echo "All files and directories have been deleted."
    else
        echo "Incorrect phrase. Exiting."
        exit 1
    fi
}


help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Configure a WireGuard VPN server and generate client configurations."
    echo
    echo "Options:"
    echo "--delete    Delete all files and directories except for the script itself."
    echo "--help      Display this help message and exit."
    echo "--qr [NUM]  Display the QR code for the specified client number or clients i.e. 1-5"
    echo
    echo "If no options are provided, the script will check if it has been run before."
    echo "If it has, it will update the existing configurations if new clients are added. If it hasn't, it will create new configurations and prompt for number of new clients to add."
}

check_and_install_packages() {
    # Determine the Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    else
        echo "Cannot determine Linux distribution. Exiting."
        exit 1
    fi

    # Define the packages to check
    declare -A packages
    packages=(["wireguard"]="wg" ["qrencode"]="qrencode")

    # Check if the packages are installed and install them if they are not
    for package in "${!packages[@]}"; do
        if ! command -v ${packages[$package]} &> /dev/null; then
            echo "$package is not installed. Do you want to install it? (y/n)"
            read user_input

            if [ "$user_input" = "y" ]; then
                case $OS in
                    "Ubuntu"|"Debian GNU/Linux")
                        sudo apt-get update
                        sudo apt-get install -y $package
                        ;;
                    "Fedora")
                        sudo dnf install -y $package
                        ;;
                    "CentOS Linux")
                        sudo yum install -y $package
                        ;;
                    "Arch Linux")
                        sudo pacman -Sy --noconfirm $package
                        ;;
                    *)
                        echo "Unsupported Linux distribution. Exiting."
                        exit 1
                        ;;
                esac
            else
                echo "Exiting."
                exit 1
            fi
        fi
    done
}


function process_qr() {
    helper_message="Please enter the numerical client number, a range (eg. 1-5), or 'q' to exit:"

    # If arguments are passed, use them instead of prompting
    if [[ $# -gt 0 ]]; then
        inputs=$@
        process_inputs $inputs
        exit 1
    fi

    # Keep prompting the user for input until they choose to quit
    while true; do
        echo $helper_message
        read inputs
        process_inputs $inputs
    done
}

function process_inputs() {
    for input in $@; do
        # Check if the user wants to quit
        if [[ $input == "q" ]]; then
            echo "Exiting..."
            return
        fi

        # Check if the input is a range
        if [[ $input =~ ^([1-9][0-9]{0,2})-([1-9][0-9]{0,2})$ ]]; then
            start=${BASH_REMATCH[1]}
            end=${BASH_REMATCH[2]}

            # Validate the range
            if [[ $start -gt $end ]]; then
                echo "Invalid range. The start of the range is greater than the end."
                continue
            fi

            # Loop through the range
            for i in $(seq $start $end); do
                display_client $i
            done
        # Validate the input
        elif [[ $input =~ ^[1-9][0-9]{0,2}$ ]]; then
            display_client $input
        else
            echo "Invalid input. $helper_message"
        fi
    done
}


function display_client() {
    # Construct the folder path
    folder_path="$CLIENT_DIR/client$1"

    # Check if the folder exists
    if [[ ! -d $folder_path ]]; then
        echo "Client folder not found for client number $1. Please try again."
        return
    fi

    # If the folder exists, run the command
    qrencode -t UTF8 "$(cat $folder_path/configurations/wg0.conf)"
}

if [ $# -eq 0 ]; then
    initial_run
    exit 0
fi

# Parse flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --delete)
        fresh_start
        shift
        ;;
    --help)
        help
        shift
        ;;
    --qr)
        # If the next argument exists and is not another flag, pass it to the function
        if [[ -n $2 ]] && [[ $2 != --* ]]; then
            process_qr $2
            shift 2
        else
            # If no argument or another flag is next, just call the function without arguments
            process_qr
            shift
        fi
        ;;
    *)
        echo "Unknown parameter: $1"
        exit 1
        ;;
    esac
done

exit 0