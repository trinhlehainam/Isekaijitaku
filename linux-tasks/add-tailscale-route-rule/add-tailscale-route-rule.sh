#!/bin/bash

# Wait for tailscaled to be fully operational
while ! systemctl is-active --quiet tailscaled; do
    echo "INFO: Waiting for tailscaled service to become active..."
    sleep 5
done

# Wait for Tailscale to be fully connected
while ! tailscale status --peers=false --json | grep -q 'Online.*true'; do
    echo "INFO: Waiting for Tailscale to connect..."
    sleep 5
done

# Check if the rule already exists
if ip rule show | grep -q "2500:.*from all to 100.64.0.0/10 lookup main"; then
    echo "INFO: Tailscale routing rule already exists"
else
    # Add the routing rule
    ip rule add to 100.64.0.0/10 priority 2500 lookup main
    echo "INFO: Tailscale routing rule has been added successfully"
fi
