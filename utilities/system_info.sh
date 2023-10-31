#!/bin/bash
# -------------------------------------------------------------
# Title: System Specification Display Script
# Description: A Bash script that concisely outputs a comprehensive 
#              summary of the system's specifications, including details 
#              about the Linux version, distribution, kernel, CPU, memory,
#              architecture, hostname, and current user.
# Dependencies: uname, lsb_release, cat, hostname, whoami
# Author: https://github.com/nerrad567/bookish-funicular
# -------------------------------------------------------------


echo "System specifications:"
echo "-----------------------------------"
echo "Linux version:"
uname -a
echo " "
echo "Linux distribution and version:"
lsb_release -a
echo " "
echo "Kernel version:"
uname -r
echo " "
echo "CPU information:"
cat /proc/cpuinfo
echo " "
echo "Memory information:"
cat /proc/meminfo
echo " "
echo "System architecture:"
uname -m
echo " "
echo "Hostname:"
hostname
echo " "
echo "Current user:"
whoami
echo " "
