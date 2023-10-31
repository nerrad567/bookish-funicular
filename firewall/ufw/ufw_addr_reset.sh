#!/bin/bash
# ==============================================================================
# UFW Rule Management Script for WireGuard VPN
# ==============================================================================
# Description:
#   This Bash script is designed to manage specific UFW (Uncomplicated FireWall)
#   rules related to the WireGuard VPN. It finds and deletes an old UFW rule
#   associated with a specific outgoing WireGuard connection, detects the current
#   IP address assigned to the network interface 'wlp58s0', and inserts a new UFW
#   rule to allow outgoing UDP traffic to the WireGuard server.
#
#   The script ensures that the system's firewall configuration remains consistent
#   with dynamic IP address changes, enhancing security by permitting only the
#   necessary traffic for the VPN connection.
#
# Dependencies:
#   bash: For script execution
#   ufw: For managing the Uncomplicated FireWall
#   ip: For querying network interfaces and addresses
#   awk, grep, cut: For text processing
#
# Usage:
#   Execute this script with appropriate permissions (usually as a superuser).
#   Ensure UFW is installed and configured on your system.
#
# Note:
#   Adjust the script and UFW rule details according to your specific network
#   configuration and WireGuard setup. The script assumes the use of a specific
#   network interface ('wlp58s0') and requires adjustment if your configuration
#   differs.
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
# ==============================================================================


# Initiate rule to empty
OLD_RULE_NUMBER=""

# Find the number of the old rule
OLD_RULE_NUMBER=$(ufw status numbered | grep "n.n.n.n 51820/udp" | grep "ALLOW OUT" | grep -E "\b(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\b on wlp58s0" | awk '{print $2}' | cut -c1)

# Find current ip address assigned to wlp58s0
# Wait for the IP address to be assigned
while true; do
    IP_ADDRESS=$(ip -4 addr show dev wlp58s0 | grep inet | awk '{print $2}' | cut -d'/' -f1)
    if [ -n "$IP_ADDRESS" ]; then
        break
    else
        sleep 1
    fi
done

# Delete the old rule if found
if [ $OLD_RULE_NUMBER ]; then
   echo "deleting old rule number: $OLD_RULE_NUMBER"
   yes | head -n 1 | ufw delete $OLD_RULE_NUMBER 
fi

# Check if UFW is enabled
if ufw status | grep -q "Status: active" && [ -n "$OLD_RULE_NUMBER" ]; then
   # echo "UFW is enabled."
   # Add the new rule at the same position as the old rule
   # allow traffic from the dynamic IP address assigned to wlp58s0 to n.n.n.n on port 51820 via wlp58s0 interface
   echo "wlp58s0 current ip: $IP_ADDRESS"
   echo "located old rule at: $OLD_RULE_NUMBER"
   ufw insert 1 allow out on wlp58s0 from $IP_ADDRESS to n.n.n.n proto udp port 51820
   echo "---------------"
   echo "$(ufw status verbose)"
   echo "---------------"

elif ufw status | grep -q "Status: active"; then
    echo "UFW enabled, existing rule not found"
    echo "UFW not updated"
    echo "---------------"
    echo "$(ufw status verbose)"
    echo "---------------"
elif ufw status | grep -q "Status: inactive"; then
    echo "UFW not enabled."
    echo "---------------"
    echo "$(ufw status verbose)"
    echo "---------------"

else
    echo "Error unknown condition:"
    echo "UFW STATUS: $(ufw status)"
    echo "OLD RULE NUMBER: \"$OLD_RULE_NUMBER\""
    echo "---------------"
    echo "$(ufw status verbose)"
    echo "---------------"

fi
