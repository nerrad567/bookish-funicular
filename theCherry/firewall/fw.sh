#!/bin/bash

# Set variables
AUTH_SSH_IP_1="n.n.n.n"
AUTH_SSH_IP_2="n.n.n.n"
AUTH_SSH_IP_3="n.n.n.n"
WG_RANGE="10.0.0.0/24"

LIMIT_RATE=15
LIMIT_BURST=30
RULES_FILE="/etc/iptables/rules.v4"


# Check if the user is running with root privileges
function check_root {
    if [ "$(id -u)" != "0" ]; then
        echo "Error: This script must be run as root" >&2
        exit 1
    fi
}

# Check if iptables is installed
function check_iptables {
    if ! command -v iptables > /dev/null; then
        echo "Error: iptables is not installed" >&2
        exit 1
    fi
}

# Print usage instructions
function print_usage {
    echo "Usage: $0 [enable|disable]"
}

# Save iptable rules
function save_rules {

    echo "Saving Rules"

    # Check if the directory exists
    if [ ! -d "/etc/iptables" ]; then
        echo "Directory /etc/iptables does not exist. Creating..."
        mkdir /etc/iptables
    fi

    # Check if the file exists
    if [ ! -e "$RULES_FILE" ]; then
        echo "File $RULES_FILE does not exist. Creating..."
        touch $RULES_FILE
    fi

    # Check if the file is writable
    if [ ! -w "$RULES_FILE" ]; then
        echo "File $RULES_FILE is not writable. Changing permissions..."
        chmod u+w $RULES_FILE
    fi

    # Save rules to file
    iptables-save > $RULES_FILE

    echo "Rules Saved"

}


# Create required user chains
function create_user_chains {
    echo "Adding user chains"

    # Create a new chain for rate limiting
    iptables -N RATE_LIMIT

    echo "Done adding user chains"

}




# Disable the firewall
function clear_firewall {
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


# Allow incoming SSH traffic from IP address authorised ip addresses
function allow_ssh {
    iptables -A INPUT -p tcp --dport 22 -s $AUTH_SSH_IP_1 -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -s $AUTH_SSH_IP_2 -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -s $AUTH_SSH_IP_3 -j ACCEPT
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
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT


    # Allow inbound traffic for HTTP and HTTPS connections
    iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT


    # Allow outgoing traffic for established connections, DNS queries, and NTP synchronization
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

    # Allow outgoing traffic for HTTP and HTTPS connections
    iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

    echo "Base firewall rules enabled enabled"
}

# Allow ICMP
function add_icmp_rules {

    echo "adding ICMP rules"
    # Allow incoming ping
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

    # Allow ping responses
    iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

    # Allow outgoing ping
    iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

    # Allow incoming ping responses
    iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

    # Allow Time Exceeded and Destination Unreachable messages, which are needed for proper operation
    iptables -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
    iptables -A OUTPUT -p icmp --icmp-type time-exceeded -j ACCEPT
    iptables -A OUTPUT -p icmp --icmp-type destination-unreachable -j ACCEPT

    echo "ICMP rules added to iptables"
}


function rate_limit {
    echo "enabling rate limiting"
    # Limit incoming traffic to mitigate DDoS attacks and SYN floods
    iptables -A INPUT -m limit --limit $LIMIT_RATE/second --limit-burst $LIMIT_BURST -j RATE_LIMIT
    iptables -A INPUT -p tcp --syn -m limit --limit 1/second --limit-burst 5 -j RATE_LIMIT
    iptables -A RATE_LIMIT -j LOG --log-prefix "FW:Rate limit exceeded: " --log-level 4
    iptables -A RATE_LIMIT -j DROP
    echo "rate limiting enabled"

}



# Check if the user is running with root privileges and if iptables is installed
check_root
check_iptables

# Parse command line arguments
if [ $# -eq 0 ]; then
    print_usage
elif [ "$1" == "enable" ]; then
    clear_firewall
    create_user_chains
    allow_ssh
    add_base_rules
    add_icmp_rules
    rate_limit
    save_rules

elif [ "$1" == "disable" ]; then
    clear_firewall
    echo "Firewall rules have been cleared."
else
    echo "Invalid argument: $1"
    print_usage
    exit 1
fi
