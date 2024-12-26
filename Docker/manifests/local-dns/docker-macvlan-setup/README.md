# AdGuard Home Macvlan Setup Service

This directory contains scripts and systemd service files for manually configuring Docker macvlan network interface for AdGuard Home container. The service will automatically create and configure the macvlan interface on system boot.

## Files

- `adguardhome-macvlan-setup.service`: Systemd service file that manages the macvlan interface
- `adguardhome-macvlan-setup.sh`: Script to create and configure the macvlan interface
- `adguardhome-macvlan-cleanup.sh`: Script to clean up the interface during shutdown
- `adguardhome-macvlan.env`: Environment configuration file shared between service and scripts

## Configuration

1. Edit the environment file to match your network settings:
```bash
sudo mkdir -p /etc/docker-macvlan.d
sudo cp adguardhome-macvlan.env /etc/docker-macvlan.d/
sudo nano /etc/docker-macvlan.d/adguardhome-macvlan.env
```

Update the following variables:
- `INTERFACE`: Your network interface name (e.g., eth0, ens33)
- `HOST_IP`: Your host's IP address
- `CONTAINER_IP`: Your AdGuard Home container's IP address
- `MACVLAN_INTERFACE`: Name for the macvlan interface (default: adguardhome-lan)

## Features

The scripts include several safety checks and informative messages:

### Setup Script
- Validates all required environment variables
- Checks if the specified network interface exists
- Avoids duplicate interface creation
- Checks for existing IP assignments
- Verifies interface state before setting it up
- Prevents duplicate route creation

### Cleanup Script
- Validates required environment variables
- Safely removes routes and interfaces only if they exist
- Provides informative messages about each operation

## Installation

1. Copy the files to their system locations:
```bash
# Copy systemd service file
sudo cp adguardhome-macvlan-setup.service /etc/systemd/system/

# Copy setup scripts and make them executable
sudo cp adguardhome-macvlan-setup.sh adguardhome-macvlan-cleanup.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/adguardhome-macvlan-setup.sh /usr/local/bin/adguardhome-macvlan-cleanup.sh
```

2. Enable and start the service:
```bash
# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable adguardhome-macvlan-setup.service

# Start the service
sudo systemctl start adguardhome-macvlan-setup.service

# Check service status and logs
sudo systemctl status adguardhome-macvlan-setup.service
journalctl -u adguardhome-macvlan-setup.service
```

## Testing

To verify the setup:
```bash
# Check if interface exists and its state
ip link show $MACVLAN_INTERFACE

# Check IP assignment
ip addr show dev $MACVLAN_INTERFACE

# View routing configuration
ip route show dev $MACVLAN_INTERFACE

# Test connection to container
ping $CONTAINER_IP
```

## Manual Usage

When running the scripts manually, make sure to source the environment file first:

```bash
# Source environment variables
source /etc/docker-macvlan.d/adguardhome-macvlan.env

# Setup macvlan interface
sudo -E /usr/local/bin/adguardhome-macvlan-setup.sh

# Cleanup when done
sudo -E /usr/local/bin/adguardhome-macvlan-cleanup.sh
```
