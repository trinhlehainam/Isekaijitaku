#!/bin/sh

# This script is triggered by networkd-dispatcher when network state changes
# Place in /etc/networkd-dispatcher/routable.d/ to run when interfaces become routable

# Add small delay to ensure network is stable
sleep 1

# Add Tailscale routing rule if it doesn't exist
if ! ip rule show | grep -q "2500:.*from all to 100.64.0.0/10 lookup main"; then
    logger -t tailscale-route-rule "INFO: Adding Tailscale routing rule..."
    ip rule add to 100.64.0.0/10 priority 2500 lookup main
    logger -t tailscale-route-rule "INFO: Tailscale routing rule has been added successfully"
fi
