#!/bin/sh

# This script is triggered by networkd-dispatcher when network state changes
# Place in /etc/networkd-dispatcher/routable.d/ to run when interfaces become routable

# Configuration
# Environment variables:
# TAILSCALE_ROUTER_IP: The LAN IP of your Tailscale subnet router (default: 192.168.0.100)
# REMOTE_SUBNETS: Space-separated list of remote subnets to route (default: 192.168.1.0/24)
#   Example: REMOTE_SUBNETS="192.168.1.0/24 192.168.2.0/24 10.0.0.0/24"

TAILSCALE_ROUTER_IP="192.168.0.100"
REMOTE_SUBNETS="192.168.1.0/24"

# Add small delay to ensure network is stable
sleep 1

# Add routes if they don't exist
# Route Tailscale subnet (100.64.0.0/10) through the Tailscale subnet router
if ! ip route show | grep -q "100.64.0.0/10 via $TAILSCALE_ROUTER_IP"; then
    logger -t static-routes "INFO: Adding Tailscale subnet route through Tailscale subnet router ($TAILSCALE_ROUTER_IP)..."
    ip route add 100.64.0.0/10 via "$TAILSCALE_ROUTER_IP"
fi

# Route remote LAN subnets through the Tailscale subnet router
for subnet in $REMOTE_SUBNETS; do
    if ! ip route show | grep -q "$subnet via $TAILSCALE_ROUTER_IP"; then
        logger -t static-routes "INFO: Adding remote LAN route for $subnet through Tailscale subnet router ($TAILSCALE_ROUTER_IP)..."
        ip route add "$subnet" via "$TAILSCALE_ROUTER_IP"
    fi
done
