#!/bin/bash

#########################################################
# Firewall and Security Script                           
#                                                        
# This script configures iptables firewall rules to      
# enhance the security of the system. It allows          
# authorized SSH access, blocks blacklisted IPs, enforces
# rate limits, allows specific services, and more.       
#                                                        
# This script is designed to be run on a Linux system as 
# the root user. It leverages iptables to create and     
# manage firewall rules that safeguard the system from   
# unauthorized access and various types of attacks.      
#                                                        
# The script supports both enabling and disabling the    
# firewall rules. When enabled, it applies a set of      
# predefined rules to restrict incoming and outgoing     
# traffic to approved channels and services. When        
# disabled, it flushes existing rules, effectively       
# turning off the firewall.                              
#                                                        
# IMPORTANT: Please review and understand the rules and  
# parameters set in this script before execution, as     
# misconfiguration could lead to unintended consequences.
#                                                        
# Usage:                                                 
#   - To enable the firewall rules:                      
#     $ ./script_name.sh enable                          
#                                                        
#   - To disable the firewall rules:                     
#     $ ./script_name.sh disable                         
#                                                        
# TODO, ideally this script can be completely reworked   
# focusing each function on it specific purpose          
# like we done for setup_allowed_packets_chain function  
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
#########################################################

# Set variables
AUTH_SSH_IP_1="n.n.n.n"
AUTH_SSH_IP_2="n.n.n.n"
WG_RANGE="10.0.0.0/24"
MAX_LOGS_PER_MIN=50
LIMIT_RATE=15
LIMIT_BURST=30

# Set the path to the blacklist file
BLACKLIST_FILE="blacklist"

# Set path to the country block list
COUNTRY_BLOCK_FILE="country_block_iptables_restore"

# Get the absolute path of the directory where the script is located
WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
echo $WORKING_DIR

# Set the path to the blacklist file
BLACKLIST_FILE="$WORKING_DIR/blacklist"

# Set path to the country block list
COUNTRY_BLOCK_FILE="$WORKING_DIR/country_block_iptables_restore"

# Check if the user is running with root privileges
function check_root {
    if [ "$(id -u)" != "0" ]; then
        echo "Error: This script must be run as root" >&2
        exit 1
    fi
}

# Check if iptables is installed
function check_iptables {
    if ! command -v iptables >/dev/null; then
        echo "Error: iptables is not installed" >&2
        exit 1
    fi
}

# Print usage instructions
function print_usage {
    echo "Usage: $0 [enable|disable]"
}

# Function to block incoming connections from IP addresses in the blacklist file
function block_blacklisted_ips() {

    # Check if the blacklist file exists
    if [ ! -f "$BLACKLIST_FILE" ]; then
        echo "BLACKLIST_FILE not found."
        return 1
    fi

    echo "Loading IP block"
    # using the -n / --noflush flag here as we manage flushing of rules elsewhere. 
    iptables-restore -n <$BLACKLIST_FILE
    echo "IP block loaded"
}

function load_country_block {

    # Check if the country block file exists
    if [ ! -f "$COUNTRY_BLOCK_FILE" ]; then
        echo "COUNTRY_BLOCK_FILE not found"
        echo $COUNTRY_BLOCK_FILE
        return 1
    fi

    echo "Loading country block"
    # using the -n / --noflush flag here as we manage flushing of rules elsewhere. 
    iptables-restore -n <$COUNTRY_BLOCK_FILE
    echo "Country block loaded"
}

# Disable the firewall
function disable_firewall {
    echo "Disabling firewall..."

    # Flush all existing rules
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F

    # Delete any user-defined chains
    iptables -X
    iptables -t nat -X
    iptables -t mangle -X

    # Set default policy for all chains to ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT

    echo "Firewall disabled"
}

# Stop Drop Ignore
function stop_drop_ignore {
    iptables -A INPUT -i ens3 -d 255.255.255.255 -j DROP

}

# Create required user chains
function create_user_chains {
    echo "Adding user chains"

    # Create a new chain for rate limiting
    iptables -N RATE_LIMIT
    
    # Create a new chain for logging
    iptables -N DROPPED_PACKETS

    iptables -N SSH_BRUTE_FORCE

    # Create the ALLOWED_PACKETS chain
    sudo iptables -N ALLOWED_PACKETS

    echo "Done adding user chains"

}

# Allow incoming SSH traffic from IP address authorised ip addresses
function allow_ssh {
    iptables -A INPUT -p tcp --dport 22 -s $AUTH_SSH_IP_1 -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -s $AUTH_SSH_IP_2 -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -s $WG_RANGE -j ACCEPT
}

# Enable the firewall
function add_base_rules {
    echo "Adding base firewall rules..."

    # Set default policy for all chains to DROP
    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP

    # Allow incoming traffic for established and related connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow loopback
    iptables -A INPUT -i lo -j ALLOWED_PACKETS
    iptables -A OUTPUT -o lo -j ALLOWED_PACKETS

    # Allow inbound traffic for HTTP and HTTPS connections
    iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ALLOWED_PACKETS

    # Allow outgoing traffic for established connections, DNS queries, and NTP synchronization
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -j ALLOWED_PACKETS
    iptables -A OUTPUT -p udp --dport 123 -j ALLOWED_PACKETS

    # Allow outgoing traffic for HTTP and HTTPS connections
    iptables -A OUTPUT -p tcp --dport 80 -j ALLOWED_PACKETS
    iptables -A OUTPUT -p tcp --dport 443 -j ALLOWED_PACKETS

    echo "Base firewall rules enabled enabled"
}

# Allow wireguard in, forward and masquerade
function add_wireguard_rules {
    echo "Allowing incoming UDP traffic on port 51820..."
    iptables -A INPUT -p udp --dport 51820 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 51820 -j ACCEPT
    iptables -A FORWARD -i wg0 -j ACCEPT
    iptables -A FORWARD -o wg0 -j ACCEPT
    iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
    echo "Incoming UDP traffic on port 51820 is now allowed"
}

# Allow ICMP
function add_icmp_rules {

    echo "adding ICMP rules"
    # Allow incoming ping
    iptables -A INPUT -p icmp --icmp-type echo-request -j ALLOWED_PACKETS

    # Allow ping responses
    iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ALLOWED_PACKETS

    # Allow outgoing ping
    iptables -A OUTPUT -p icmp --icmp-type echo-request -j ALLOWED_PACKETS

    # Allow incoming ping responses
    iptables -A INPUT -p icmp --icmp-type echo-reply -j ALLOWED_PACKETS

    # Allow Time Exceeded and Destination Unreachable messages, which are needed for proper operation
    iptables -A INPUT -p icmp --icmp-type time-exceeded -j ALLOWED_PACKETS
    iptables -A INPUT -p icmp --icmp-type destination-unreachable -j ALLOWED_PACKETS
    iptables -A OUTPUT -p icmp --icmp-type time-exceeded -j ALLOWED_PACKETS
    iptables -A OUTPUT -p icmp --icmp-type destination-unreachable -j ALLOWED_PACKETS

    echo "ICMP rules added to iptables"
}

# Log all dropped packets
function dropped_packets {
    echo "Logging all dropped packets with a maximum of $MAX_LOGS_PER_MIN logs per minute..."

    # Add a rule to the INPUT chain to jump to the LOGGING chain
    iptables -A INPUT -j DROPPED_PACKETS
    iptables -A DROPPED_PACKETS -m conntrack --ctstate NEW -m limit --limit $MAX_LOGS_PER_MIN/minute -j LOG --log-prefix "FW:Dropped: "
    iptables -A DROPPED_PACKETS -j DROP

    echo "All dropped packets are now being logged with a maximum of $MAX_LOGS_PER_MIN logs per minute"
}

# allow packets and log
function setup_allowed_packets_chain {

    # Add the logging rule to the ALLOWED_PACKETS chain
    sudo iptables -A ALLOWED_PACKETS -j LOG --log-prefix "iptables allowed: " --log-level 4

    # Add the accept rule to the ALLOWED_PACKETS chain
    sudo iptables -A ALLOWED_PACKETS -j ACCEPT
}

# rate limiting seems unnecessary so we are not calling this function for now
#
function rate_limit {
    echo "enabling rate limiting"
    # Limit SSH login attempts
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j SSH_BRUTE_FORCE
    iptables -A SSH_BRUTE_FORCE -m recent --name sshbf --rttl --rcheck --hitcount 3 --seconds 60 -j LOG --log-prefix "FW:SSH brute force "
    iptables -A SSH_BRUTE_FORCE -m recent --name sshbf --rttl --rcheck --hitcount 3 --seconds 60 -j DROP
    iptables -A SSH_BRUTE_FORCE -m recent --name sshbf --set -j ACCEPT

    # Limit incoming traffic to mitigate DDoS attacks and SYN floods
    iptables -A INPUT -m limit --limit $LIMIT_RATE/second --limit-burst $LIMIT_BURST -j RATE_LIMIT
    iptables -A INPUT -p tcp --syn -m limit --limit 1/second --limit-burst 5 -j RATE_LIMIT
    iptables -A RATE_LIMIT -j LOG --log-prefix "FW:Rate limit exceeded: " --log-level 4
    iptables -A RATE_LIMIT -j DROP
    echo "rate limiting enabled"

}

function add_torrent_rules {
    iptables -A INPUT -p tcp -m tcp --dport 42121 -j ACCEPT
    iptables -A INPUT -p udp -m udp --dport 42121 -j ACCEPT
}

# Check if the user is running with root privileges and if iptables is installed
check_root
check_iptables

# Parse command line arguments
if [ $# -eq 0 ]; then
    print_usage
elif [ "$1" == "enable" ]; then
    disable_firewall
    create_user_chains
    allow_ssh
    block_blacklisted_ips
    load_country_block
    stop_drop_ignore
    setup_allowed_packets_chain
    add_base_rules
    add_wireguard_rules
    add_icmp_rules
    #    add_torrent_rules
    #    rate_limit
    dropped_packets

elif [ "$1" == "disable" ]; then
    disable_firewall
else
    print_usage
fi
