#!/bin/bash

# ------------------------------------------------------------------------------
# Title: Aesthetic Log Filter Script
# Description: Elegantly filters and enhances the visibility of system logs, 
#              with customizable settings for inclusion and exclusion of specific 
#              log components. Enrich your log monitoring experience with 
#              color-coded outputs and tailored log details.
# Author: https://github.com/nerrad567/bookish-funicular
# ------------------------------------------------------------------------------


# Configuration
include_time_date=true
include_host_name=false
host_name="blueMuffin kernel:"
remove_parts=()
#remove_parts=("SYN" "MAC" "LEN" "TOS" "PREC" "TTL" "ID" "WINDOW" "RES" "URGP" "ACK" "MARK" "PSH" "DF")
#exclude_patterns=("DST=255.255.255.255" "DST=224.0.0.251" "DST=224.0.0.1")
exclude_patterns=("DST=255.255.255.255" "DST=224.0.0.251" "DST=224.0.0.1")
filter_d="DROP:"
filter_a="AUDIT:"


# ANSI escape code for color
RED='\033[0;31m'
LIME='\033[0;32m'
# ANSI escape code to reset color
NC='\033[0m'

# Function to check if line should be excluded
line_to_exclude() {
    local line="$1"
    local exclude_patterns=("${!2}")

    for pattern in "${exclude_patterns[@]}"; do
        if [[ $line == *"$pattern"* ]]; then
            return 0
        fi
    done

    return 1
}

# Function to filter lines
filter_lines() {
    local line="$1"
    local include_time_date="$2"
    local include_host_name="$3"
    local host_name="$4"
    local remove_parts=("${!5}")

    if [ "$include_time_date" = false ]; then
        line=$(echo "$line" | sed -E 's/^[^[]*\[//')
    fi

    if [ "$include_host_name" = false ]; then
        line=$(echo "$line" | sed "s/$host_name//")
    fi

    for part in "${remove_parts[@]}"; do
        line=$(echo "$line" | sed -E "s/$part(=[^ ]*)?( )?//g")
    done

    if [[ $line == *"$filter_d"* ]]; then
        echo -e "${RED}$line${NC}"
    elif [[ $line == *"$filter_a"* ]]; then
        echo -e "${LIME}$line${NC}"
    else
        echo "$line"
    fi
}

# Read journalctl output
journalctl -f | while read -r line; do
    if (line_to_exclude "$line" exclude_patterns[@]); then
        continue
    fi

    if [[ $line == *"$filter_d"* ]] || [[ $line == *"$filter_a"* ]]; then
        filtered_line=$(filter_lines "$line" "$include_time_date" "$include_host_name" "$host_name" remove_parts[@])
        echo -e "$filtered_line"
    fi
done
