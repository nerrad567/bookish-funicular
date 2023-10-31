#!/bin/bash

# note: this script was likely for a pi server setup, maybe
################################################################################
# This script is a Bash script designed to set up and manage a Linux firewall
# using iptables rules. The firewall is designed to provide security for a system
# while allowing specific types of network traffic to pass through, both over a
# WireGuard VPN connection (if available) and the regular network interface.
#
# Let's break down the script step by step to understand its functionality:
#
# Trusted DNS Servers: The script defines three trusted DNS servers with IP
# addresses: 8.8.8.8, 149.112.112.112, and 9.9.9.9. These servers will be used
# for DNS resolution.
#
# Configuration Functions:
# - configure_base_rules(): Clears existing firewall rules and sets the default
#   policies for incoming, outgoing, and forwarded traffic to be dropped. It then
#   sets rules to accept traffic that is part of established or related connections.
# - allow_loopback(): Allows traffic on the loopback interface.
# - allow_ssh_home(): Allows SSH traffic from the home LAN (IP range 192.168.0.0/24)
#   and implements rate limiting for SSH connections.
# - allow_outgoing_traffic(): Allows outgoing traffic for common services such as
#   DNS, HTTP, and HTTPS to the trusted DNS servers and other network services.
#
# WireGuard-Specific Functions:
# - allow_ssh_wg0(): Allows SSH traffic over the WireGuard VPN interface (wg0) from
#   the IP range 10.0.0.0/27.
# - nfs_service(): Allows NFS (Network File System) service over WireGuard,
#   including specific ports used for various aspects of NFS communication.
# - syncthing_service(): Allows Syncthing service over WireGuard, including specific
#   ports for TCP and UDP communication.
#
# VPN Connection and Network Services:
# - wireguard_vpn_connection(): Allows outgoing WireGuard VPN traffic to a specific
#   IP address on port 51820.
# - allow_ntp_traffic(): Allows Network Time Protocol (NTP) traffic for server time
#   synchronization.
#
# ICMP and Connection Rate Limiting:
# - handle_icmp(): Allows various ICMP (Internet Control Message Protocol)
#   requests and responses, including ping requests.
# - hit_rates(): Implements rate limiting for SSH connections, ICMP requests,
#   and limits the number of simultaneous SYN packets.
#
# Final Drop Rules and Logging:
# - set_final_drop_rules(): Sets the final rules to drop incoming, outgoing,
#   and forwarded traffic. Also, it enables SYN flood protection and logs dropped
#   packets.
#
# Applying Firewall Rules:
# - apply_firewall_rules(): This function checks whether the WireGuard VPN interface
#   (wg0) is available. If it is, it applies a set of firewall rules optimized for
#   a VPN connection. If not, it applies a more general set of rules for non-VPN use.
#
# Main Script:
# - The script starts by checking if the argument --clear is provided. If provided,
#   it clears all existing iptables rules and sets the default policies to allow
#   all traffic. If not provided, it goes on to execute the apply_firewall_rules
#   function.
# - After applying the initial rules, the script enters an infinite loop where it
#   repeatedly checks whether the WireGuard interface exists (wg0). If the state of
#   the WireGuard interface changes (up or down), the script updates the firewall
#   rules accordingly using the apply_firewall_rules function.
#
# The script is designed to create a firewall setup that enforces strict security
# policies while allowing specific types of traffic to pass through. It also takes
# into consideration the presence of a WireGuard VPN connection and adjusts the
# rules accordingly. 
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
################################################################################

#trusted dns servers
dns1="8.8.8.8"
dns2="149.112.112.112"
dns3="9.9.9.9"

# Function to flush existing rules and set default policies
configure_base_rules() {
    iptables -F
    iptables -X
    iptables -t nat -F

    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP

    #Implement stateful firewall: Ensure the firewall is stateful by allowing only RELATED and ESTABLISHED connections for both incoming and outgoing traffic:
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

}

# Function to allow traffic on the loopback interface
allow_loopback() {
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
}

# Function to allow SSH traffic to home LAN and enable rate limiting
allow_ssh_home() {
    iptables -A INPUT -p tcp --dport 22 -s 192.168.0.0/24 -m state --state NEW,ESTABLISHED -j ACCEPT
}

# Function to allow outgoing traffic for common services, DNS, HTTP, HTTPS
allow_outgoing_traffic() {
    ##dns
    iptables -A OUTPUT -p udp -d $dns1 --dport 53 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -p udp -d $dns2 --dport 53 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -p tcp -d $dns1 --dport 53 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -p tcp -d $dns2 --dport 53 -m state --state NEW -j ACCEPT

    #http, https used for updates etc
    iptables -A OUTPUT -p tcp --dport 80 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 443 -m state --state NEW -j ACCEPT
}

# Function to allow SSH traffic over WireGuard (wg0)
allow_ssh_wg0() {
    iptables -A INPUT -p tcp -i wg0 --dport 22 -s 10.0.0.0/27 -m state --state NEW,ESTABLISHED -j ACCEPT
}

# Function to allow NFS service over WireGuard (wg0)
nfs_service() {
    # NFS (TCP and UDP port 2049):
    iptables -A INPUT -i wg0 -s 10.0.0.0/27 -p tcp --dport 2049 -m state --state NEW -j ACCEPT
    iptables -A INPUT -i wg0 -s 10.0.0.0/27 -p udp --dport 2049 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -o wg0 -d 10.0.0.0/27 -p tcp --sport 2049 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -o wg0 -d 10.0.0.0/27 -p udp --sport 2049 -m state --state NEW -j ACCEPT

    # Mountd (TCP and UDP port 4000):
    iptables -A INPUT -i wg0 -s 10.0.0.0/27 -p tcp --dport 4000 -m state --state NEW -j ACCEPT
    iptables -A INPUT -i wg0 -s 10.0.0.0/27 -p udp --dport 4000 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -o wg0 -d 10.0.0.0/27 -p tcp --sport 4000 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -o wg0 -d 10.0.0.0/27 -p udp --sport 4000 -m state --state NEW -j ACCEPT

    #Nlockmgr (TCP and UDP port 4001):
    iptables -A INPUT -i wg0 -s 10.0.0.0/27 -p tcp --dport 4001 -m state --state NEW -j ACCEPT
    iptables -A INPUT -i wg0 -s 10.0.0.0/27 -p udp --dport 4001 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -o wg0 -d 10.0.0.0/27 -p tcp --sport 4001 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -o wg0 -d 10.0.0.0/27 -p udp --sport 4001 -m state --state NEW -j ACCEPT

    # Portmapper (TCP and UDP port 111):
    iptables -A INPUT -i wg0 -s 10.0.0.0/27 -p tcp --dport 111 -m state --state NEW -j ACCEPT
    iptables -A INPUT -i wg0 -s 10.0.0.0/27 -p udp --dport 111 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -o wg0 -d 10.0.0.0/27 -p tcp --sport 111 -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -o wg0 -d 10.0.0.0/27 -p udp --sport 111 -m state --state NEW -j ACCEPT
}

# Function to allow Syncthing service over WireGuard (wg0)
syncthing_service() {
    iptables -A INPUT -i wg0 -p tcp -s 10.0.0.0/27 --dport 8384 -m state --state NEW,ESTABLISHED -j ACCEPT

    iptables -A INPUT -i wg0 -p tcp -s 10.0.0.0/27 --dport 22000 -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -o wg0 -p tcp -d 10.0.0.0/27 --dport 22000 -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -o wg0 -p tcp -d 10.0.0.0/27 --sport 22000 -m state --state NEW,ESTABLISHED -j ACCEPT

    iptables -A INPUT -i wg0 -p udp -s 10.0.0.0/27 --dport 22000 -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -o wg0 -p udp -d 10.0.0.0/27 --dport 22000 -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -o wg0 -p udp -d 10.0.0.0/27 --sport 22000 -m state --state NEW,ESTABLISHED -j ACCEPT

}

# Function to allow WireGuard VPN connection
wireguard_vpn_connection() {
    iptables -A OUTPUT -p udp --dport 51820 -d n.n.n.n -m state --state NEW,ESTABLISHED -j ACCEPT
}

# Function to allow NTP traffic for server time synchronisation
allow_ntp_traffic() {
    iptables -A OUTPUT -p udp --dport 123 -m state --state NEW -j ACCEPT
}

# Function to allow ICMP requests globally
handle_icmp() {
    # Allow incoming echo-request (ping) packets
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

    # Allow outgoing echo-request (ping) packets
    iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

    # Allow other necessary ICMP types
    iptables -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type parameter-problem -j ACCEPT
}

# Function to restrict the number of attempted connections to a service
hit_rates() {
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
    iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 6 -j DROP

    iptables -A INPUT -i wg0 -p tcp --dport 22 -m state --state NEW -m recent --set
    iptables -A INPUT -i wg0 -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 6 -j DROP

    iptables -A INPUT -p icmp -m limit --limit 1/s --limit-burst 5 -j ACCEPT

    iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 10 -j DROP



}

# Function to set final drop rules
set_final_drop_rules() {

    #Enable SYN flood protection: Protect against SYN flood attacks by limiting the number of simultaneous SYN packets:
    iptables -A INPUT -p tcp ! --src 10.0.0.0/27 ! --syn -m state --state NEW -j DROP
    #iptables -A INPUT -p tcp ! --src 10.0.0.0/27 --tcp-flags !0x17/0x02 -m state --state NEW -j DROP

    iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "INPUT DROP: " --log-level 7
    iptables -A OUTPUT -m limit --limit 5/min -j LOG --log-prefix "OUTPUT DROP: " --log-level 7
    iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "FORWARD DROP: " --log-level 7

    iptables -A INPUT -j DROP
    iptables -A OUTPUT -j DROP
    iptables -A FORWARD -j DROP
}



# Function to apply firewall rules based on the existence of wg0
apply_firewall_rules() {
    if ip link show wg0 > /dev/null 2>&1; then
        configure_base_rules
        wireguard_vpn_connection
        allow_loopback
        allow_ssh_home
        allow_ssh_wg0
        allow_outgoing_traffic
        nfs_service
        syncthing_service
        allow_ntp_traffic
        handle_icmp
        hit_rates
        set_final_drop_rules
        echo "wg0 up, routing configured. FlameOn"
    else
        configure_base_rules
        allow_loopback
        allow_ssh_home
        allow_outgoing_traffic
        allow_ntp_traffic
        handle_icmp
        set_final_drop_rules
        echo "Unable to detect wg0, VPN rules not configured. FlameOn"
    fi
}

# Main script
if [ "$1" == "--clear" ]; then
    iptables -F
    iptables -X
    iptables -t nat -F

    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT

    echo "iptable rules have been cleared and reset to allow all traffic."

else

    apply_firewall_rules
    wg0_exists=$(ip link show wg0 > /dev/null 2>&1 && echo "yes" || echo "no")

    while true; do
        sleep 5
        current_wg0_exists=$(ip link show wg0 > /dev/null 2>&1 && echo "yes" || echo "no")
        if [ "$wg0_exists" != "$current_wg0_exists" ]; then
            apply_firewall_rules
            wg0_exists="$current_wg0_exists"
        fi
    done
fi
