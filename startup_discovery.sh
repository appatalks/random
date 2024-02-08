#!/bin/bash
#
# Startup Discovery
# Tested on Ubuntu 20.04 Based OS
# Lists Service Startup Sequence and latency to complete. 
# Uses journalctl and systemd-analyze blame to review start time and latency to complete sequence since last boot.
#
# Usage: sudo /bin/bash startup_discovery.sh

# Define the logfile
LOG_FILE="/var/log/service_startup_details_$(date +'%Y-%m-%d_%H-%M-%S').log"

# Start logging
echo "Service Startup Duration, Order, and Start Timestamp - $(date)" > "$LOG_FILE"
echo "================================================================" >> "$LOG_FILE"

# Function to get the start timestamp of a service
get_service_start_timestamp() {
    local service_name="$1"
    # Fetch the earliest log timestamp for this service since the last reboot
    journalctl -u "$service_name" -b --no-pager | grep "Starting" | head -n 1 | awk '{print $1, $2, $3}'
}

# Use systemd-analyze blame to get startup times for all services
systemd-analyze blame | while read -r duration service; do
    # Check if the service is enabled
    if systemctl is-enabled "$service" &> /dev/null; then
        # Get the start timestamp for the service
        timestamp=$(get_service_start_timestamp "$service")
        # Log the duration, service name, and its start timestamp
        echo "Duration: $duration, Service: $service, Started at: $timestamp" >> "$LOG_FILE"
    fi
done

echo "Analysis complete. Please check $LOG_FILE for details."
