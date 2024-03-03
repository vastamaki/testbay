#!/bin/bash

# Function to clear the console
clear_console() {
    clear
}

# Check if script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo." >&2
    exit 1
fi

# Function to list available network interfaces and prompt for selection
select_interface() {
    echo "Available network interfaces:"
    ip link show | awk -F ': ' 'NF > 1 {print NR")",$2}'
    read -p "Enter the number of the interface: " selection
    INTERFACE_NAME=$(ip link show | awk -F ': ' 'NR == '$selection' && NF > 1 {print $2}')
    if [ -z "$INTERFACE_NAME" ]; then
        echo "Invalid selection. Aborted."
        exit 1
    fi
}

# Function to prompt for VLAN ID
enter_vlan_id() {
    read -p "Enter the VLAN ID: " VLAN_ID
}

# Function to prompt for IP address
enter_ip_address() {
    read -p "Enter the IP address: " IP_ADDRESS
}

# Function to prompt for subnet
enter_subnet() {
    read -p "Enter the subnet prefix length (e.g., 24 for /24 subnet): /" SUBNET_PREFIX
    SUBNET="/$SUBNET_PREFIX"
}

# Function to propose default gateway based on user's input
propose_gateway() {
    read -p "Do you want to use the default gateway for the provided IP address? (y/n): " use_default_gateway
    use_default_gateway=$(echo "$use_default_gateway" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    if [[ "$use_default_gateway" == "y" ]]; then
        GATEWAY=$(echo "$IP_ADDRESS" | awk -F. '{print $1"."$2"."$3".1"}')
    else
        echo "Enter the gateway: "
        read -r GATEWAY
    fi
}

# Function to prompt for DNS nameserver
enter_dns_nameserver() {
    read -p "Enter the DNS nameserver: " DNS_NAMESERVER
}

# Prompt for interface selection
select_interface

# Prompt for VLAN ID
enter_vlan_id

# Prompt for IP address
enter_ip_address

# Prompt for subnet
enter_subnet

# Propose default gateway
propose_gateway

# Prompt for DNS nameserver
enter_dns_nameserver

INTERFACE="$INTERFACE_NAME.$VLAN_ID"

# Display configuration information
clear_console
echo "Interface: $INTERFACE"
echo "IP Address: $IP_ADDRESS"
echo "Subnet: ${SUBNET:1}" # Remove the leading '/'
echo "Gateway: $GATEWAY"
echo "DNS nameserver: $DNS_NAMESERVER"

# Confirmation prompt
read -p "Do you want to proceed with the above configuration? (y/n): " confirm
confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
if [ "$confirm" != "y" ]; then
    echo "Aborted."
    exit 0
fi

# Create the new network interface
echo "Creating interface $INTERFACE..."
ip link add link $INTERFACE_NAME name $INTERFACE type vlan id $VLAN_ID

# Assign the IP address to the network interface
echo "Assigning IP address $IP_ADDRESS/$SUBNET_PREFIX to interface $INTERFACE..."
ip addr add $IP_ADDRESS/$SUBNET_PREFIX dev $INTERFACE

# Start the network interface
echo "Starting interface $INTERFACE..."
ip link set dev $INTERFACE up

# Configure the network interface
echo "Configuring interface $INTERFACE..."
