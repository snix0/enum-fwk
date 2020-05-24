if [[ $# -lt 1 ]]; then
    echo "Usage $(basename $0) SUBNET"
    exit
fi

RANGE=$1

# Host discovery
echo "Task host_discovery starting..."
nmap -sn $RANGE -oA discovered_hosts

if [[ $? -ne 0 ]]; then
    echo "Task host_discovery failed."
    exit 1
fi

# Generate shortlist of hosts
echo "Task generate_host_shortlist starting..."
cut -f2 -d' ' discovered_hosts.gnmap | sed '1d;$d' > discovered_hosts.list

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

# TCP scan all ports
echo "Task scan_tcp_all starting..."
for host in $(cat discovered_hosts.list); do (if [ ! -f $host/scantcpall.xml ]; then nmap -sT -p- $host -oA $host/scantcpall; xsltproc -o $host/scantcpall.html $host/scantcpall.xml; fi) & done

if [[ $? -ne 0 ]]; then
    echo "Task scan_tcp_all failed."
    exit 1
fi

# UDP scan all ports
echo "Task scan_udp_all starting..."
for host in $(cat discovered_hosts.list); do (if [ ! -f $host/scanudpall.xml ]; then nmap -sU -p- $host -oA $host/scanudpall; xsltproc -o $host/scanudpall.html $host/scanudpall.xml; fi) & done

if [[ $? -ne 0 ]]; then
    echo "Task scan_udp_all failed."
    exit 1
fi

wait

# TODO More thorough TCP scan on found ports
echo "Done"
