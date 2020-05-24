#!/bin/bash

## Web server enumeration
# Description: Enumeration script for discovering hidden web directories, website vulnerabilities, etc. Requires run.sh to be run first to set the groundwork.
# Ports: 80, 443
# Dependencies: gobuster, nikto, wfuzz, wordlists

ports="80"
helper_path=$(dirname "$0")/one-liners/oscp

for port in $ports; do
    "$helper_path"/scan-hosts-for-port.sh "$PWD" $port > $port.hosts
    if [[ -s $port.hosts ]]; then
        for host in $(cat $port.hosts); do
            gobuster -q dir -u "http://$host" -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -o $host/gobuster.$port
            nikto -h "$host" -o $host/nikto.$port.html
            wfuzz -w /usr/share/wordlists/dirb/common.txt -f $host/wfuzz.$port.html,htm --hc 404 "http://$host/FUZZ"
        done
    fi
done
