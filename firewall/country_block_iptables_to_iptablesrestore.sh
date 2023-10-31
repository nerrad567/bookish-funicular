#!/bin/bash

##############################################################################################
# This script reads IP/CIDR blocks from an input file name assigned to $input_file
# it generates an iptables-restore ruleset to block incoming traffic from those IP ranges.
# The generated rules are written to an output file named assigned to output_file.
# Each rule drops incoming traffic from a specific IP/CIDR.
# for ip blocks/CIDR ranges see https://www.countryipblocks.net/acl.php
# this script will convert those in the "Linux iptables" and "CIDR" format
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
##############################################################################################

# Define the input and output files
input_file="country_block"                  # Name of the input file containing IP/CIDR blocks and iptables rules
output_file="country_block_iptables_restore"   # Name of the output file for consolidated iptables rules

# Clean up previous output file if it exists
rm -f "$output_file"

# Process each line in the input file
while IFS= read -r line
do
    # Remove leading and trailing whitespace
    line_trimmed=$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')

    # Check if the line is an iptables entry
    if [[ "$line_trimmed" =~ ^iptables ]]; then
        # Extract IP/CIDR from the iptables entry
        ip_cidr=$(echo "$line_trimmed" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+')
        # Format and write the rule to the output file
        echo "-A INPUT -s $ip_cidr -j DROP" >> "$output_file"
    elif [[ "$line_trimmed" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        # Format and write the rule to the output file
        echo "-A INPUT -s $line_trimmed -j DROP" >> "$output_file"
    fi
done < "$input_file"

# Add iptables filter table markers
echo "*filter" | cat - "$output_file" > tmp && mv tmp "$output_file"
echo "COMMIT" >> "$output_file"

# End of script

