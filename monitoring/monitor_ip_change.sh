#!/bin/bash
# -----------------------------------------------------------------------------------
# Title:  IP Change Detector and Handler
# Description: monitor IP address changes on a specific network interface,
#              implementing a brief pause to ensure accuracy in detection. Upon 
#              identification of an IP alteration, the script triggers a predefined 
#              action, maintaining network integrity and adaptability. Crafted with 
#              precision, this script is a testament to proactive network management.
# Author: https://github.com/nerrad567/bookish-funicular
# -----------------------------------------------------------------------------------

INTERFACE="wlp58s0"
LAST_IP=""

ip monitor address dev "$INTERFACE" | while read -r line; do
    if echo "$line" | grep -q "inet"; then
        sleep 3 # wait for 3 seconds before checking the IP address
        CURRENT_IP=$(ip -4 addr show dev "$INTERFACE" | grep inet | awk '{print $2}' | cut -d'/' -f1)

        if [ "$CURRENT_IP" != "$LAST_IP" ]; then
            LAST_IP="$CURRENT_IP"
            ufw_addr_reset.sh
        fi
    fi
done
