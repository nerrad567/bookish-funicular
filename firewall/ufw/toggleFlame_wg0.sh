#!/bin/bash
# ==============================================================================
# UFW Configuration and WireGuard Management Script
# ==============================================================================
# Description:
#   This Bash script automates the process of configuring UFW (Uncomplicated FireWall)
#   and managing the WireGuard VPN service based on the current UFW rules.
#   If UFW is set to deny outgoing connections, the script stops the WireGuard service,
#   resets UFW rules, and configures UFW to allow all outgoing and deny all incoming
#   connections.
#   If UFW is set to allow outgoing connections, the script configures specific UFW
#   rules to control the traffic through different interfaces and ports, sets UFW to
#   deny all incoming and outgoing connections by default, enables IPv6 traffic
#   denial, starts the WireGuard service, and mounts all disks.
#
# Dependencies:
#   bash: For script execution
#   sudo: For executing commands with superuser privileges
#   ufw: For managing the Uncomplicated FireWall
#   systemctl: For managing system services and units
#   ip: For querying and managing network interfaces and addresses
#   awk, grep, cut: For text processing
#   mount: For mounting filesystems
#
# Note:
#   This script requires superuser privileges to execute most of its commands.
#   Ensure to run it with appropriate permissions and understand the UFW and
#   WireGuard configurations to avoid potential network issues.
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
# ==============================================================================


#if [ "$(sudo ufw status | grep 'Status: active')" != "" ]; then
#
#
if [ "$(sudo ufw status verbose | grep 'deny (outgoing)')" != "" ]; then
    # stop wireguard service for wg0
    sudo systemctl stop wg-quick@wg0.service

    # remove all UFW rules
     yes | head -n 1 | sudo ufw reset

    # set default policies to allow all traffic
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw enable

else
    # get the IP address assigned to the wlp58s0 interface
    ip_address=$(ip -4 addr show dev wlp58s0 | grep inet | awk '{print $2}' | cut -d'/' -f1)

    # allow traffic from the dynamic IP address assigned to wlp58s0 to n.n.n.n on port 51820 via wlp58s0 interface
    sudo ufw allow out on wlp58s0 from $ip_address to n.n.n.n proto udp port 51820

    # allow all traffic to 192.168.0.99 on another interface
    #sudo ufw allow in to 192.168.0.99
    sudo ufw allow out on wlp58s0 from $ip_address to 192.168.0.99
    sudo ufw allow out on wlp58s0 from $ip_address to 192.168.0.1 proto tcp port 80

    # allow traffic only through wireguard interface (IPv4 only)
    #sudo ufw allow in on wg0 from any to any proto any
    #sudo ufw allow out on wg0 from any to any proto any
    sudo ufw allow out on wg0 from 10.0.0.10 to any
    # set default policy to deny
    sudo ufw default deny incoming
    sudo ufw default deny outgoing

    # enable the UFW firewall
    sudo ufw enable

    # add an additional rule to deny IPv6 traffic
    sudo ip6tables -P INPUT DROP
    sudo ip6tables -P FORWARD DROP
    sudo ip6tables -P OUTPUT DROP

    # start wireguard service for wg0
    sudo systemctl start wg-quick@wg0.service

    #mount disks
    sudo mount -a
fi
