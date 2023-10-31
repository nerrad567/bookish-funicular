#!/bin/bash
# ==============================================================================
# UFW Log Viewer Script
# ==============================================================================
# Description:
#   This script provides a user-friendly interface to view UFW (Uncomplicated Firewall)
#   block logs in real-time or view recent block logs with optional color highlighting
#   for better readability.
#
# Usage:
#   Run the script with bash. User will be prompted to choose between live log viewing
#   or viewing recent logs. The logs are filtered and highlighted for better readability.
#
# Dependencies:
#   - bash: For script execution and control flow.
#   - journalctl: For accessing and monitoring system logs.
#   - grep: For filtering log entries.
#   - sed: For text processing and color highlighting.
#   - less: For paginated viewing of logs.
#
# Configuration:
#   - No external configuration required. Customize the script as needed.
#
# Notes:
#   - Ensure you have the required permissions to access system logs and run the script
#     with appropriate privileges.
#   - Adjust the text processing commands as necessary to suit your specific log format
#     and preferences.
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
# ==============================================================================

echo "Welcome to the UFW log viewer!"
echo "Please choose an option:"
echo "1. Show live UFW BLOCK log"
echo "2. Show recent UFW BLOCK log"

read choice

case $choice in
  1)
    sudo journalctl -f | grep --line-buffered -i ufw | grep --line-buffered -i '\[UFW BLOCK\]' | sed -E 's/ThinkPad-T470s-W10DG |MAC=[^ ]+|LEN=[^ ]+|TOS=[^ ]+|PREC=[^ ]+|TTL=[^ ]+|ID=[^ ]+|kernel: |WINDOW=|RES=|SYN|URGP=| DF | PROTO=2 /\o033[0m/g; s/IN=([^ ]+)/\o033[32mIN=\1\o033[0m/g; s/OUT=([^ ]+)/\o033[32mOUT=\1\o033[0m/g; s/SRC=([^ ]+)/\o033[34mSRC=\1\o033[0m/g; s/DST=([^ ]+)/\o033[34mDST=\1\o033[0m/g; s/(IN=|OUT=|SRC=|DST=)[ ]+//g; s/(IN=|OUT=|SRC=|DST=)$//g; s/\[UFW BLOCK\]/\o033[31m&\o033[0m/g'
    ;;
  2)
    sudo journalctl -r | grep -i ufw | grep -i '\[UFW BLOCK\]' | sed -E 's/ThinkPad-T470s-W10DG |MAC=[^ ]+|LEN=[^ ]+|TOS=[^ ]+|PREC=[^ ]+|TTL=[^ ]+|ID=[^ ]+|kernel: |WINDOW=|RES=|SYN|URGP=| DF | PROTO=2 /\o033[0m/g; s/IN=([^ ]+)/\o033[32mIN=\1\o033[0m/g; s/OUT=([^ ]+)/\o033[32mOUT=\1\o033[0m/g; s/SRC=([^ ]+)/\o033[34mSRC=\1\o033[0m/g; s/DST=([^ ]+)/\o033[34mDST=\1\o033[0m/g; s/(IN=|OUT=|SRC=|DST=)[ ]+//g; s/(IN=|OUT=|SRC=|DST=)$//g; s/\[UFW BLOCK\]/\o033[31m&\o033[0m/g' | less -R
    ;;
  *)
    echo "Invalid choice. Please choose 1 or 2."
    ;;
esac
