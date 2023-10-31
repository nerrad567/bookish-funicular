#!/bin/bash
# ==============================================================================
# UFW Log Filter and Color Highlight Script
# ==============================================================================
# Description:
#   This script monitors and filters UFW (Uncomplicated Firewall) logs in real-time,
#   highlighting UFW block entries in red for easy visibility. It also provides
#   options to include/exclude specific log parts and IPs for a cleaner output.
#
# Configuration Options:
#   - include_time_date: Toggle to include/exclude date and time in the log output.
#   - include_host_name: Toggle to include/exclude the host name in the log output.
#   - host_name: The host name to filter out from the log entries.
#   - remove_parts: An array of log parts to remove for a cleaner output.
#   - exclude_ips: An array of IPs to exclude from the log output.
#
# Usage:
#   Run the script with bash. Ensure you have the required permissions to access
#   system logs. Customize the configuration section as per your requirements.
#
# Dependencies:
#   - bash: For script execution and control flow.
#   - journalctl: For accessing and monitoring system logs.
#   - sed, echo, read: For text processing and output.
#
# Note:
#   This script is tailored for systems using UFW and systemd's journal. Adjust
#   the script as necessary to suit your specific system configuration and
#   preferences.
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
# ==============================================================================


# Configuration
include_time_date=true
include_host_name=false
host_name="ThinkPad-T470s-W10DG kernel:"
#remove_parts=("MAC" "LEN" "TOS" "PREC" "TTL" "ID" "WINDOW" "RES" "URGP" "ACK" "MARK" "PROTO" "IN" "OUT" "SRC" "DST" "SPT" "DPT" "PSH" "DF")
remove_parts=("MAC" "LEN" "TOS" "PREC" "TTL" "ID" "WINDOW" "RES" "URGP" "ACK" "MARK" "PROTO" "PSH" "DF")
exclude_ips=("9.9.9.9" "239.255.255.250" "224.0.0.1" "224.0.0.251" "192.168.0.255" "n.n.n.n")

# ANSI escape code for red color
RED='\033[0;31m'
# ANSI escape code to reset color
NC='\033[0m'

# Function to filter lines
filter_lines() {
    local line="$1"
    local include_time_date="$2"
    local include_host_name="$3"
    local host_name="$4"
    local remove_parts=("${!5}")
    local exclude_ips=("${!6}")

    for ip in "${exclude_ips[@]}"; do
        if [[ $line == *"$ip"* ]]; then
            return
        fi
    done

    if [ "$include_time_date" = false ]; then
        line=$(echo "$line" | sed -E 's/^[^[]*\[//')
    fi

    if [ "$include_host_name" = false ]; then
        line=$(echo "$line" | sed "s/$host_name//")
    fi

    for part in "${remove_parts[@]}"; do
        line=$(echo "$line" | sed -E "s/$part(=[^ ]*)?( )?//g")
    done

    if [[ $line == *"[UFW BLOCK]"* ]]; then
        echo -e "${RED}$line${NC}"
    else
        echo "$line"
    fi
}

# Read journalctl output
journalctl -f | while read -r line; do
    if [[ $line == *"[UFW BLOCK]"* ]] || [[ $line == *"[UFW AUDIT]"* ]]; then
        filtered_line=$(filter_lines "$line" "$include_time_date" "$include_host_name" "$host_name" remove_parts[@] exclude_ips[@])
        echo -e "$filtered_line"
    fi
done
