#!/bin/bash

# Function to show usage
show_usage() {
    echo "Usage: $0 <seconds> <local_ip>"
    echo "Example: $0 20 172.31.24.10"
    echo -e "\nAvailable local IPs:"
    ip -4 addr show | grep -w inet | awk '{print $2}' | cut -d/ -f1
}

# Check if both arguments are provided
if [ $# -ne 2 ]; then
    show_usage
    exit 1
fi

# Validate the time argument is a positive number
if ! [[ $1 =~ ^[0-9]+$ ]] || [ "$1" -eq 0 ]; then
    echo "Error: Please provide a positive number of seconds"
    show_usage
    exit 1
fi

# Validate IP address format
if ! [[ $2 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid IP address format"
    show_usage
    exit 1
fi

COLLECTION_TIME=$1
LOCAL_IP=$2

# Verify the IP exists on the system
if ! ip addr | grep -q "$LOCAL_IP"; then
    echo "Warning: IP $LOCAL_IP not found on any local interface"
    echo "Available IPs:"
    ip -4 addr show | grep -w inet | awk '{print $2}' | cut -d/ -f1
    echo -n "Continue anyway? (y/n): "
    read -r CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Collecting outgoing established connections from $LOCAL_IP over $COLLECTION_TIME seconds..."

# Create a temporary file to store connections
TEMP_FILE=$(mktemp)
trap 'rm -f $TEMP_FILE' EXIT  # Clean up temp file when script exits

# Collect data for specified seconds
echo "Collecting data..."
for ((i=1; i<=$COLLECTION_TIME; i++)); do
    # Show progress percentage
    PERCENT=$((i * 100 / COLLECTION_TIME))
    echo -ne "Progress: $PERCENT% ($i/$COLLECTION_TIME seconds)\r"
    
    # Debug: Show all current connections first
    echo -e "\nDebug: Current ss output at second $i:" >> "$TEMP_FILE"
    ss -ntu state established >> "$TEMP_FILE"
    
    # Collect current established outgoing connections for specific IP
    echo "Filtered connections:" >> "$TEMP_FILE"
    ss -ntu state established | 
        grep -v "Netid" |
        grep -v "127\.0\.0\.1" |
        grep -v "::1" |
        awk -v ip="$LOCAL_IP" '
        $4 ~ ip {
            printf "Local: %-25s Remote: %s\n", $4, $5
        }' >> "$TEMP_FILE"
    
    echo "---" >> "$TEMP_FILE"
    sleep 1
done
echo -e "\nCollection complete!\n"

# Show the debug output
echo "Debug output:"
cat "$TEMP_FILE"

echo -e "\nFiltered unique remote peer connections from $LOCAL_IP:"
echo "----------------------------------------"
ss -ntu state established | 
    grep -v "Netid" |
    grep -v "127\.0\.0\.1" |
    grep -v "::1" |
    awk -v ip="$LOCAL_IP" '
    $4 ~ ip {
        print $5
    }' | sort -u

# Show current connection count
echo -e "\nCurrent active connections for reference:"
ss -ntu state established