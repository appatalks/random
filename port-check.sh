#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <host> <port1> [port2] [port3] ..."
    exit 1
fi

HOST=$1
shift
PORTS="$@"

# Timeout value in seconds
TIMEOUT=5

# Loop through each port and check if it's open
for port in $PORTS; do
    # Check if the port is open using TCP
    if timeout $TIMEOUT bash -c "echo > /dev/tcp/$HOST/$port" 2>/dev/null; then
        echo "Port $port on $HOST is open"
    else
        echo "Port $port on $HOST is closed or unreachable"
    fi
done
