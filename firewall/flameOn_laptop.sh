#!/bin/bash

################################################################################
# This script toggles the state of a basic Linux firewall using iptables rules.
# When the script is run, it checks the current state of the firewall. If the
# firewall is enabled (configured to drop most incoming traffic), the script
# disables it, allowing all traffic to pass through. If the firewall is disabled,
# the script enables it and configures specific rules to allow selected traffic.
# The specific rules include permitting established and related connections,
# allowing loopback traffic, and allowing SSH traffic on port 22 from the
# 192.168.0.0/16 network.
#
# The script provides feedback about the action taken, whether the firewall has
# been enabled or disabled, and what types of traffic are permitted.
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
################################################################################

# Check if firewall is enabled
if iptables -S | grep -- "-P INPUT DROP"; then
    # Firewall is enabled, so disable it and allow all traffic
    iptables -F
    iptables -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    echo "Firewall disabled. All traffic is allowed."
else
    # Firewall is disabled, so enable it and allow specific traffic
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT
    iptables -A INPUT -p tcp -s 192.168.0.0/16 --dport 22 -j ACCEPT

    echo -e "Firewall enabled. Only solicited inbound traffic, localhost \\nand SSH on port 22 from 192.168.0.0/16 are allowed."
fi
