#!/bin/bash
#
# Startup Discovery
# Tested on Ubuntu 20.04 Based OS
# Lists Service Startup Sequence and latency to complete. 
# Uses journalctl and systemd-analyze blame to review start time and latency to complete sequence since last boot.
#
# Usage: sudo /bin/bash startup_discovery.sh

# Define the logfile with a dynamic name including the current date and time
LOG_FILE="/var/log/service_and_docker_startup_details_$(date +'%Y-%m-%d_%H-%M-%S').log"

# Start logging for system services
echo "System Service Startup Duration, Order, and Start Timestamp - $(date)" > "$LOG_FILE"
echo "=====================================================================" >> "$LOG_FILE"

# Function to format timestamp to a unified style
format_timestamp() {
    local raw_timestamp="$1"
    # Convert to 'Thu 2024-02-08 20:11:03 UTC' format, if possible
    date -d "$raw_timestamp" +"%Y-%m-%d %T %Z" 2>/dev/null || echo "$raw_timestamp"
}

# Function to get the start timestamp of a service
get_service_start_timestamp() {
    local service_name="$1"
    # Attempt to fetch the earliest log timestamp for this service since the last reboot that indicates it was starting
    local timestamp=$(journalctl -u "$service_name" -b --no-pager | grep -m1 -E "Starting|Started" | awk '{print $1, $2, $3}')
    
    # If no timestamp was found in the journal, use systemctl status to find the active time
    if [ -z "$timestamp" ]; then
        # Extract the Active line, focusing on the date/timestamp after 'since'
        timestamp=$(systemctl status "$service_name" | grep "Active:" | sed -n 's/.*since \(.*\);.*/\1/p')
    fi
    
    # Format the timestamp for consistency
    echo $(format_timestamp "$timestamp")
}

# Use systemd-analyze blame to get startup times for all services
systemd-analyze blame | while read -r duration service; do
    # Check if the service is enabled
    if systemctl is-enabled "$service" &> /dev/null; then
        # Get the start timestamp for the service
        timestamp=$(get_service_start_timestamp "$service")
        # Log the duration, start timestamp, and service name
        echo "Duration: $duration, Started at: $timestamp, Service: $service" >> "$LOG_FILE"
    fi
done

# Check if Docker is installed and running
if command -v docker &> /dev/null && docker info &> /dev/null; then
    # Start logging for Docker containers
    echo -e "\nDocker Containers Startup Details - $(date)" >> "$LOG_FILE"
    echo "================================================" >> "$LOG_FILE"

    # List all containers, extract their start times, names, and IDs, then sort by start time
    docker ps --format '{{.CreatedAt}} {{.ID}}' | sort | while read -r line; do
        # created_at=$(echo "$line" | awk '{print $1, $2, $3, $4}')
        created_at=$(echo "$line" | awk '{print $1, $2, $4}')
        container_id=$(echo "$line" | awk '{print $5}')

        # Use docker inspect to get a cleaner container name without UUIDs
        container_name=$(docker inspect --format '{{.Name}}' $container_id | sed 's/^\///' | sed -E 's/-[0-9a-f]{8,}-[0-9a-f]{4,}-[0-9a-f]{4,}-[0-9a-f]{4,}-[0-9a-f]{12,}//g')

        # Log the start time and container name
        echo "Started at: $created_at, Container Name: $container_name" >> "$LOG_FILE"
    done
else
    echo -e "\nDocker is not installed or not running. Skipping Docker containers section." >> "$LOG_FILE"
fi

echo "Analysis complete. Please check $LOG_FILE for details."
