#!/bin/bash

# -------------------------------------------------------------
# Title: Comprehensive Network Status Script
# Description: A Bash script that aggregates various network statistics
#              including speed test results, IP information, and data transfer 
#              statistics. It leverages external utilities like speedtest-cli, 
#              curl, jq, and vnstat to provide a detailed and user-friendly 
#              network status report.
# Dependencies: speedtest-cli, curl, jq, vnstat
# Usage: Execute with optional flags -s (speed test), -i (IP information), 
#        or -t (data transfer statistics) to run specific tests.
# Author: https://github.com/nerrad567/bookish-funicular
# -------------------------------------------------------------


run_speedtest() {
    echo "Running speed test..."
    result=$(speedtest-cli --simple)
    download=$(echo "$result" | grep "Download:" | awk '{print $2,$3}')
    upload=$(echo "$result" | grep "Upload:" | awk '{print $2,$3}')
    ping=$(echo "$result" | grep "Ping:" | awk '{print $2,$3}')
    echo "Download speed: $download"
    echo "Upload speed: $upload"
    echo "Ping: $ping"
}

run_ipinfo() {
    data=$(curl -s ipinfo.io)
    echo -e "\033[1;31mIP Address:\033[0m $(echo $data | jq -r '.ip')"
    echo -e "\033[1;31mHostname:\033[0m $(echo $data | jq -r '.hostname')"
    echo -e "\033[1;33mCity:\033[0m $(echo $data | jq -r '.city')"
    echo -e "\033[1;34mRegion:\033[0m $(echo $data | jq -r '.region')"
    echo -e "\033[1;35mCountry:\033[0m $(echo $data | jq -r '.country')"
    echo -e "\033[1;35mPostal Code:\033[0m $(echo $data | jq -r '.postal')"
    echo -e "\033[1;36mLocation:\033[0m $(echo $data | jq -r '.loc')"
    echo -e "\033[1;37mASN:\033[0m $(echo $data | jq -r '.asn')"
    echo -e "\033[1;32mOrganization:\033[0m $(echo $data | jq -r '.org')"
}

run_vnstat() {
     data=$(vnstat)
     echo $data
}

while getopts ":sit" opt; do
  case $opt in
    s)
      run_speedtest
      exit 0
      ;;
    i)
      run_ipinfo
      exit 0
      ;;
    t)
      run_vnstat
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

run_ipinfo
vnstat
run_speedtest
