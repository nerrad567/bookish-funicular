#!/bin/bash

##########################################################
# Automated IP Blacklisting Script                        
#                                                         
# This script monitors a log file for specific log        
# entries indicating unauthorized access attempts or      
# other security incidents. When such entries are         
# detected, the script adds the corresponding IP addresses
# to a blacklist and invokes a separate firewall script   
# for enforcement. The script runs in a loop at a set     
# interval, allowing continuous monitoring and response   
# to security events.                                     
#                               
#
# Author:
#   https://github.com/nerrad567/bookish-funicular                          
##########################################################

# Set a flag to indicate if the script should keep running
keep_running=true

# Set the log file and blacklist file paths
LOG_FILE="/var/log/kern.log"
BLACKLIST_FILE="blacklist"

# Set the interval (in minutes) at which to run the script
INTERVAL=5

# Set firewall script path
flameon=""

# Define an array of prefixes to search for in the log file
declare -a PREFIXES=("FW:Dropped: " "FW:SSH brute force " "FW:Rate limit exceeded: ")

# Define an array of IP addresses and ranges to exclude from the blacklist
declare -a EXCLUDES=("n.n.n.n" "n.n.n.n" "n.n.n.n/24" "n.n.n.n")

# Define a function to handle the SIGTERM signal
function sigterm_handler() {
    echo "Received SIGTERM signal. Exiting..."
    keep_running=false
}

# Register the sigterm_handler function as the SIGTERM signal handler
trap sigterm_handler SIGTERM


# Create the blacklist file if it doesn't exist
if [ ! -f "$BLACKLIST_FILE" ]; then
    echo "Creating blacklist file..."
    echo "*filter" > "$BLACKLIST_FILE"
fi

# Function to check if an IP address is in an excluded range
function is_excluded() {
    local ip=$1  # Assign the first argument (IP address) to the variable "ip"

    # Loop through each value in the "EXCLUDES" array
    for exclude in "${EXCLUDES[@]}"; do

        # Check if the value contains a slash ("/"), indicating an IP range
        if [[ "$exclude" == *"/"* ]]; then
            # If it's an IP range, extract the start and end values of the range

            # Extract the range start by converting IP components to a numeric value
            local range_start=$(echo "$exclude" | awk -F'[./]' '{printf "%.0f", $1*256^3 + $2*256^2 + $3*256 + $4}')
            
            # Calculate the range end by using the subnet mask to determine the IP count in the range
            local range_end=$((range_start + 2**(32 - $(echo "$exclude" | awk -F'/' '{print $2}')) - 1))
            
            # Convert the current IP address to a numeric value
            local ip_num=$(echo "$ip" | awk -F'.' '{printf "%.0f", $1*256^3 + $2*256^2 + $3*256 + $4}')
            
            # Check if the current IP is within the calculated range
            if ((ip_num >= range_start && ip_num <= range_end)); then
                return 0  # Return success (IP is excluded)
            fi
        elif [[ "$ip" == "$exclude" ]]; then
            # If it's not an IP range but an exact IP match, return success
            return 0  # Return success (IP is excluded)
        fi
    done

    return 1  # If IP is not excluded by any condition, return failure
}

# This script is intended to run in a loop with a specified interval, while a boolean variable "keep_running" is set to true.

# The loop begins here and will continue as long as "keep_running" is true.
while $keep_running; do
    # Display a message indicating that the script is scanning the log file for matching entries.
    echo "Scanning log file for matching entries..."

    # Remove any lines containing the text "COMMIT" from the specified blacklist file.
    sed -i '/COMMIT/d' "$BLACKLIST_FILE"

    # Loop through each prefix in the array "PREFIXES."
    for prefix in "${PREFIXES[@]}"; do
        # Use the "grep" command to search for log entries containing the current prefix and extract unique IP addresses from them.
        # storing them as a space seperated string
        ips=$(grep "$prefix" "$LOG_FILE" | grep -Po '(\d{1,3}\.){3}\d{1,3}' | sort -u)

        # Loop through each extracted IP address. Essentially waits until it is passed data via the <<<"$ips" at the end of the loop until all data in string is processed
        while read -r ip; do
            # Call the function "is_excluded" to check if the IP address is in the exclude list or range.
            if is_excluded "$ip"; then
                # Display a message indicating that the IP address is found but excluded from the blacklist.
                echo "IP address $ip found, but excluded from blacklist."
                # Continue to the next IP address.
                continue
            fi

            # Check if the IP address is not already in the blacklist file.
            if ! grep -q "$ip" "$BLACKLIST_FILE"; then
                # If not, append a rule to the blacklist file to drop incoming traffic from this IP.
                echo "IP address $ip found. Adding to blacklist..."
                echo "-A INPUT -s $ip -j DROP" >> "$BLACKLIST_FILE"
            fi

        # Complete the loop through IP addresses.
        done <<<"$ips"
    # Complete the loop through prefixes.
    done

    # Add a "COMMIT" line to the end of the blacklist file.
    echo "COMMIT" >> "$BLACKLIST_FILE"

    # Run a script named "flameOn.sh" to enable some functionality.
    echo "Running flameOn.sh script..."
    $flameon enable

    # Display a message indicating that the script is going to sleep for the specified interval before scanning again.
    echo "Sleeping for $INTERVAL minutes before scanning again..."
    # Sleep for the specified interval in minutes before resuming the loop.
    sleep $((INTERVAL * 60))

# The loop ends here.
done

echo "Script exited gracefully."
