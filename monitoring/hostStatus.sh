#!/bin/bash
# -----------------------------------------------------------------------------------
# Title: Dynamic Network Health Monitor
# Description: script designed to continuously assess the 
#              availability of specified network hosts. Utilizing ping, it provides 
#              real-time, color-coded status updates, ensuring immediate visual 
#              feedback on network health. Tailored with customizable settings for 
#              check frequency and timeout, this script is an essential tool for 
#              network administrators aiming for uninterrupted connectivity.
# Author: https://github.com/nerrad567/bookish-funicular
# -----------------------------------------------------------------------------------

# Define the list of hosts to check
hosts=(
    10.0.0.1
#    10.0.0.2
#    10.0.0.3
#    10.0.0.4
#    10.0.0.5
#    10.0.0.6
#    10.0.0.7
#    10.0.0.8
#    10.0.0.9
    10.0.0.10
    10.0.0.11
    10.0.0.12
    10.0.0.14
    10.0.0.20
    10.0.0.21
)

# Define the frequency of checks in seconds
frequency=5

# Define timeout for ping command in seconds
timeout=1

# Define ANSI color codes
green=$(tput setaf 2)
red=$(tput setaf 1)
reset=$(tput sgr0)

# Loop forever
while true; do
    # Print the header indicating a check is in progress
    clear
    printf "${green}%s${reset}\n" "Checking hosts at $(date)"

    # Loop over each host and check its status
    for host in "${hosts[@]}"; do
        status=$(ping -c 1 -W $timeout "$host" >/dev/null 2>&1 && echo "${green}UP${reset}" || echo "${red}DOWN${reset}")
        printf "%-15s %-5s\n" "${host}:" "$status"
    done

    # Sleep for the specified frequency before checking again
    sleep $frequency
done
