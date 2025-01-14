#!/bin/bash

# Function to show usage
show_usage() {
    echo "Usage: $0 <seconds> <ip_address>"
    echo "Example: $0 20 172.31.24.10"
    echo -e "\nAvailable network interfaces and IPs:"
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

echo "Collecting network connections over $COLLECTION_TIME seconds for IP $LOCAL_IP..."

# Create a temporary file to store connections
TEMP_FILE=$(mktemp)
trap 'rm -f $TEMP_FILE' EXIT  # Clean up temp file when script exits

# Collect data for specified seconds
echo "Collecting data..."
for ((i=1; i<=$COLLECTION_TIME; i++)); do
    # Show progress percentage
    PERCENT=$((i * 100 / COLLECTION_TIME))
    echo -ne "Progress: $PERCENT% ($i/$COLLECTION_TIME seconds)\r"
    
    # Collect current connections and append to temp file
    ss -ntua | 
        grep -v "Netid" |
        grep -v "127.0.0" |
        grep -v "::1" |
        awk -v ip="$LOCAL_IP" '
            {
                if ($4 ~ ip || $5 ~ ip) 
                    printf "State: %-12s Local: %-25s Remote: %-25s\n", $2, $4, $5
            }' >> "$TEMP_FILE"
    
    sleep 1
done
echo -e "\nCollection complete!\n"

# Show unique connections found during the collection period
echo "Unique connections found over $COLLECTION_TIME seconds for IP $LOCAL_IP:"
echo "----------------------------------------"
sort -u "$TEMP_FILE"

# Show listening ports separately
echo -e "\n-------------------"
echo "Current listening ports:"
echo "-------------------"
ss -ntul | grep -v "Netid" | grep LISTEN
