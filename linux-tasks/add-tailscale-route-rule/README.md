# Tailscale Route Setup

This service sets up a routing rule for Tailscale to properly handle traffic to the `100.64.0.0/10` subnet.

## Installation

1. Copy the script to the system:
```bash
sudo cp add-tailscale-route-rule.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/add-tailscale-route-rule.sh
```

2. Copy the service file:
```bash
sudo cp add-tailscale-route-rule.service /etc/systemd/system/
```

3. Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable add-tailscale-route-rule.service
sudo systemctl start add-tailscale-route-rule.service
```

## Verification

Check the service status:
```bash
sudo systemctl status add-tailscale-route-rule.service
```

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
