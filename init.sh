#!/bin/bash

if [[ $# -lt 1 ]]; then
    echo "Usage $(basename $0) SUBNET"
    exit
fi

RANGE=$1

# Check if user is root
if [[ ${EUID} -ne 0 ]]; then
    echo "This script should be run as root due to some features requiring elevated privileges (e.g. UDP scanning)."
    exit 1
fi

# Check if nmap is already running
if ps aux | grep nmap | grep -q -v grep; then
    read -e -p "Nmap scan is currently running. Would you like to proceed anyway? [yN]: "
    if [[ ! ${REPLY} =~ [Yy] ]]; then
        exit
    fi
fi

# Host discovery
echo "Task host_discovery starting..."
if [ -f discovered_hosts.xml ]; then
    echo "discovered_hosts.xml already exists. Skipping task."
else
    nmap -sn $RANGE -oA discovered_hosts
    echo "Task host_discovery completed"
fi

if [[ $? -ne 0 ]]; then
    echo "Task host_discovery failed."
    exit 1
fi

# Generate shortlist of hosts
echo "Task generate_host_shortlist starting..."
if [ -f discovered_hosts.list ]; then
    echo "discovered_hosts.list already exists. Skipping task."
else
    cut -f2 -d' ' discovered_hosts.gnmap | sed '1d;$d' > discovered_hosts.list
    echo "Task genernate_host_shortlist completed"
fi

if [[ $? -ne 0 ]]; then
    echo "Task generate_host_shortlist failed."
    exit 1
fi

# TODO Find hidden hosts

# Create output folders
if [ ! -f discovered_hosts.list ]; then
    echo "Could not find discovered_hosts.list. Exiting..."
    exit 1
fi

echo "Task create_outdirs starting..."
for host in $(cat discovered_hosts.list); do if [ ! -d $host ]; then mkdir $host; fi; done

if [[ $? -ne 0 ]]; then
    echo "Task create_outdirs failed."
    exit 1
fi

# Cleaning up incomplete scans from previous runs
echo "Task incomplete_port_discov_scan_cleanup starting..."
for host in $(cat discovered_hosts.list); do if [ -f $host/scantcpall.xml ] && ! grep -q 'exit="success"' $host/scantcpall.xml; then echo "Incomplete TCP scan detected for $host. Cleaning up..."; rm -f $host/scantcpall*; fi; done
for host in $(cat discovered_hosts.list); do if [ -f $host/scanudpall.xml ] && ! grep -q 'exit="success"' $host/scanudpall.xml; then echo "Incomplete UDP scan detected for $host. Cleaning up..."; rm -f $host/scanudpall*; fi; done
echo "Task incomplete_port_discov_scan_cleanup completed"

# TCP scan all ports
echo "Task scan_tcp_all starting..."
for host in $(cat discovered_hosts.list); do (if [ ! -f $host/scantcpall.xml ]; then nmap -sT -p- $host -oA $host/scantcpall && xsltproc -o $host/scantcpall.html $host/scantcpall.xml; fi) & done

if [[ $? -ne 0 ]]; then
    echo "Task scan_tcp_all failed."
    exit 1
fi

# UDP scan all ports
echo "Task scan_udp_all starting..."
for host in $(cat discovered_hosts.list); do (if [ ! -f $host/scanudpall.xml ]; then nmap -sU --top-ports 1000 $host -oA $host/scanudpall && xsltproc -o $host/scanudpall.html $host/scanudpall.xml; fi) & done

if [[ $? -ne 0 ]]; then
    echo "Task scan_udp_all failed."
    exit 1
fi

wait

echo "Task generate_tcp_port_shortlist starting..."
for host in $(cat discovered_hosts.list); do grep open $host/scantcpall.nmap | cut -f1 -d'/' | grep -v '[^0-9]' > $host/tcp_ports.list; done
echo "Task generate_tcp_port_shortlist completed"

echo "Task generate_udp_port_shortlist starting..."
for host in $(cat discovered_hosts.list); do grep open $host/scanudpall.nmap | cut -f1 -d'/' | grep -v '[^0-9]' > $host/udp_ports.list; done
echo "Task generate_udp_port_shortlist completed"

# Cleanup quick scan
echo "Task incomplete_port_quick_scan_cleanup starting..."
for host in $(cat discovered_hosts.list); do if [ -f $host/quicktcp.xml ] && ! grep -q 'exit="success"' $host/quicktcp.xml; then echo "Incomplete TCP scan detected for $host. Cleaning up..."; rm -f $host/quicktcp*; fi; done
for host in $(cat discovered_hosts.list); do if [ -f $host/quickudp.xml ] && ! grep -q 'exit="success"' $host/quickudp.xml; then echo "Incomplete UDP scan detected for $host. Cleaning up..."; rm -f $host/quickudp*; fi; done
echo "Task incomplete_port_quick_scan_cleanup completed"

# Quick port scan
for host in $(cat discovered_hosts.list); do (if [[ ! -f $host/quicktcp.html && -s $host/tcp_ports.list ]]; then nmap -sT -p $(paste -sd, $host/tcp_ports.list) -sC -sV -O -A -oA $host/quicktcp $host && xsltproc -o $host/quicktcp.html $host/quicktcp.xml; fi) & done
for host in $(cat discovered_hosts.list); do (if [[ ! -f $host/quickudp.html && -s $host/udp_ports.list ]]; then nmap -sU -p $(paste -sd, $host/udp_ports.list) -sC -sV -O -A -oA $host/quickudp $host && xsltproc -o $host/quickudp.html $host/quickudp.xml; fi) & done

wait

# Generate searchsploit reports
echo "Task generate_sploit_reports starting..."
find . \( -name 'quicktcp.xml' -o -name 'quickudp.xml' \) ! -exec bash -c 'test -f $(dirname "$1")/$(basename "$1" .xml).sploit.url' bash {} ';' -exec bash -c 'searchsploit -w --nmap {} | tr -s " " > $(dirname "$1")/$(basename "$1" .xml).sploit.url &' bash {} \;
find . \( -name 'quicktcp.xml' -o -name 'quickudp.xml' \) ! -exec bash -c 'test -f $(dirname "$1")/$(basename "$1" .xml).sploit.local' bash {} ';' -exec bash -c 'searchsploit --nmap {} | tr -s " " > $(dirname "$1")/$(basename "$1" .xml).sploit.local &' bash {} \;
echo "Task generate_sploit_reports completed"

wait
