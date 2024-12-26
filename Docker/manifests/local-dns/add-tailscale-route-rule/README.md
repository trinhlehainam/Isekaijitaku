# Tailscale Route Setup

This script maintains a routing rule for Tailscale to properly handle traffic to the `100.64.0.0/10` subnet. It uses networkd-dispatcher to automatically restore the rule when network interfaces change.

## Installation

1. Install networkd-dispatcher:
```bash
sudo apt install networkd-dispatcher
```

2. Copy the script to networkd-dispatcher's routable events directory:
```bash
sudo cp 99-tailscale-route-rule.sh /etc/networkd-dispatcher/routable.d/
sudo chmod +x /etc/networkd-dispatcher/routable.d/99-tailscale-route-rule.sh
```

The script will be triggered automatically when network interfaces become routable.

## How It Works

### Purpose

This script is particularly important when you have multiple Tailscale nodes on the same private LAN:
- When one Tailscale node acts as a router for the network
- Other Tailscale nodes need to route their Tailscale subnet traffic through this router
- Prevents routing loops and ensures proper traffic flow in multi-node setups

The routing rule ensures that traffic to the Tailscale subnet (100.64.0.0/10) is properly routed through the main routing table, allowing it to be forwarded to your designated Tailscale router instead of being handled locally.

### Network Events That Reset Rules

The routing rule might be reset in several scenarios:
- Adding/removing network interfaces (`ip link add/del`)
- Network interface state changes
- System network reconfiguration
- Network manager operations

### Automatic Recovery

The script is triggered by networkd-dispatcher whenever:
- Network interfaces become routable
- Network configuration changes
- System resumes from sleep/hibernate
- Network interfaces are added or removed

When triggered, it:
1. Verifies if the Tailscale routing rule exists
2. Adds the rule if it's missing

## Verification

Check if the routing rule is applied:
```bash
ip rule show
```

You should see a line like this in the output:
```
2500:   from all to 100.64.0.0/10 lookup main
```

This indicates that:
- Priority is set to 2500
- Rule applies to all source IPs
- Destination is the Tailscale subnet (100.64.0.0/10)
- Uses the main routing table for lookup

## Troubleshooting

### Viewing Logs

Check the system logs for script activity:
```bash
journalctl -t tailscale-route
```

### Common Issues

1. Rule not being restored:
   - Check if networkd-dispatcher is running: `systemctl status networkd-dispatcher`
   - Check script permissions: `ls -l /etc/networkd-dispatcher/routable.d/99-tailscale-route-rule.sh`
   - Check system logs: `journalctl -t tailscale-route`

2. Multiple rules appearing:
   - This shouldn't happen as the script checks for existing rules
   - If it does, you can clean up with: `sudo ip rule del to 100.64.0.0/10 priority 2500`

## Notes

- The script is idempotent and safe to run multiple times
- It will automatically add the rule whenever network interfaces become routable
- The script uses systemd's journal for logging with the tag `tailscale-route`
