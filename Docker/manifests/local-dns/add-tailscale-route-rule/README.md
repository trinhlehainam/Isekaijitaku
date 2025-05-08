# Tailscale Network Configuration

This repository contains scripts for managing Tailscale network configuration using networkd-dispatcher. It handles both routing rules and static routes to ensure proper traffic flow in a Tailscale network with subnet routers.

## Network Architecture

### Tailscale Subnet Router
- A Tailscale node configured as a subnet router (e.g., at LAN IP 192.168.0.100)
- Advertises routes for local subnets to the Tailscale network
- Acts as a gateway for other nodes to access different subnets

### Other Nodes
- Machines that need to access resources through the Tailscale subnet router
- May or may not run Tailscale themselves
- Need proper routing configuration to reach other subnets

## Components

1. `99-tailscale-route-rule.sh`: Maintains routing rules for Tailscale subnet traffic
2. `99-static-routes.sh`: Manages static routes for inter-subnet communication through the Tailscale subnet router

## Installation

1. Install networkd-dispatcher:
```bash
sudo apt install networkd-dispatcher
```

2. Configure the subnet router IP:
Edit `99-static-routes.sh` and set your Tailscale subnet router's LAN IP:
```bash
TAILSCALE_ROUTER_IP="192.168.0.100"  # Replace with your subnet router's LAN IP
```

3. Copy the scripts to networkd-dispatcher's routable events directory:
```bash
sudo cp 99-tailscale-route-rule.sh /etc/networkd-dispatcher/routable.d/
sudo cp 99-static-routes.sh /etc/networkd-dispatcher/routable.d/
sudo chmod +x /etc/networkd-dispatcher/routable.d/99-tailscale-route-rule.sh
sudo chmod +x /etc/networkd-dispatcher/routable.d/99-static-routes.sh
```

The scripts will be triggered automatically when network interfaces become routable.

## Configuration

The script supports configuration through environment variables:

1. `TAILSCALE_ROUTER_IP` (default: "192.168.0.100")
   - The LAN IP address of your Tailscale subnet router
   - Example: `TAILSCALE_ROUTER_IP="192.168.0.100"`

2. `REMOTE_SUBNETS` (default: "192.168.1.0/24")
   - Space-separated list of remote subnets to route through the Tailscale subnet router
   - Example: `REMOTE_SUBNETS="192.168.1.0/24 192.168.2.0/24 10.0.0.0/24"`

To use custom values, you can run the script with environment variables:
```bash
sudo TAILSCALE_ROUTER_IP="192.168.0.100" REMOTE_SUBNETS="192.168.1.0/24 192.168.2.0/24" /etc/networkd-dispatcher/routable.d/99-static-routes.sh
```

## How It Works

### Routing Rules (99-tailscale-route-rule.sh)

This script maintains routing rules for the Tailscale subnet. It's particularly important when:
- Multiple Tailscale nodes exist on the same private LAN
- One Tailscale node acts as a subnet router for the network
- Other Tailscale nodes need to route their Tailscale subnet traffic through this router

The routing rule ensures traffic to the Tailscale subnet (100.64.0.0/10) is properly routed through the main routing table.

### Static Routes (99-static-routes.sh)

This script maintains static routes for inter-subnet communication through your Tailscale subnet router. It:
- Routes Tailscale subnet traffic (100.64.0.0/10) through your subnet router
- Routes traffic to other advertised subnets through your subnet router
- Ensures routes persist across network changes and system reboots
- Includes error checking and logging

## Network Events That Trigger Scripts

The scripts are triggered by networkd-dispatcher whenever:
- Network interfaces become routable
- Network configuration changes
- System resumes from sleep/hibernate
- Network interfaces are added or removed

## Verification

### Check Routing Rules
```bash
ip rule show
```

Expected output should include:
```
2500:   from all to 100.64.0.0/10 lookup main
```

### Check Static Routes
```bash
ip route show
```

Expected output should include (replace 192.168.0.100 with your subnet router's IP):
```
100.64.0.0/10 via 192.168.0.100
192.168.1.0/24 via 192.168.0.100
```

## Troubleshooting

### Viewing Logs

For routing rules:
```bash
journalctl -t tailscale-route
```

For static routes:
```bash
journalctl -t static-routes
```

### Common Issues

1. Rules/Routes not being restored:
   - Check if networkd-dispatcher is running: `systemctl status networkd-dispatcher`
   - Check script permissions in `/etc/networkd-dispatcher/routable.d/`
   - Check system logs using the commands above
   - Verify your subnet router's IP is correct in the configuration

2. Multiple rules/routes appearing:
   - Scripts check for existing entries before adding new ones
   - To clean up routing rules: `sudo ip rule del to 100.64.0.0/10 priority 2500`
   - To clean up static routes (replace 192.168.0.100 with your subnet router's IP):
```bash
sudo ip route del 100.64.0.0/10 via 192.168.0.100
sudo ip route del 192.168.1.0/24 via 192.168.0.100
```

## Notes

- The scripts are idempotent and safe to run multiple times
- They use systemd's journal for logging
- All changes are automatically restored after network changes
- This approach is more reliable than using netplan configuration in Proxmox VMs since it won't be overwritten by cloud-init on reboot
- Make sure to replace the example subnet router IP (192.168.0.100) with your actual Tailscale subnet router's LAN IP
