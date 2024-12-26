# AdGuard Home with Docker Network Options

This directory contains two Docker Compose configurations for running AdGuard Home with different networking options:

1. `docker-compose.yaml`: Basic AdGuard Home setup
2. `tailscale-compose.yaml`: AdGuard Home with Tailscale VPN integration

## Network Architecture

The setup uses two separate networks for optimal performance and security:

### 1. Internal Bridge Network (dns)
An isolated bridge network for internal communication between AdGuard Home and Unbound:

```yaml
networks:
  dns:
    driver: bridge
    internal: true  # Isolated from external networks
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

Benefits:
- Secure internal communication
- Isolated from external networks
- Efficient container-to-container communication
- No external routing or NAT issues

### 2. External Macvlan Network (adguardhome-macvlan)
A macvlan network for direct host access to AdGuard Home, using a single IP:

```yaml
networks:
  adguardhome-macvlan:
    driver: macvlan
    driver_opts:
      parent: eth0  # Change this to your network interface
    ipam:
      config:
        - subnet: 192.168.X.0/24  # Single IP for AdGuard Home
          gateway: 192.168.X.1     # Change to match your network gateway
          ip_range: 192.168.X.Y/32  # Restrict to single IP
```

Benefits:
- Direct network integration
- No port forwarding needed
- Native network visibility
- Preserves client IP addresses
- Single IP allocation prevents network pollution
- Host-container communication support

## Network Creation with Docker CLI

If you prefer to manage networks externally from Docker Compose:

### Internal Bridge Network
```bash
# Create internal bridge network
docker network create dns \
  --driver bridge \
  --internal \
  --subnet 172.20.0.0/16

# Verify network configuration
docker network inspect dns
```

### External Macvlan Network
```bash
# Create macvlan network with single IP and host recognition
docker network create adguardhome-macvlan \
  --driver macvlan \
  --subnet 192.168.X.0/24 \
  --gateway 192.168.X.1 \
  --ip-range 192.168.X.Y/32 \
  --aux-address="host=192.168.X.Z" \
  --option parent=eth0

# Verify network configuration
docker network inspect adguardhome-macvlan
```

Then update your compose files to use external networks:

```yaml
networks:
  dns:
    external: true
  adguardhome-macvlan:
    external: true
```

### Remove Networks
```bash
# Remove networks when no longer needed
docker network rm dns
docker network rm adguardhome-macvlan
```

## Host-Container Communication

### 1. Get Host IP Address

First, determine your host's IP address:

```bash
# Show IP addresses for network interface
ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1

# Or use this to see all interfaces
ip -br addr show
```

Note: Replace `eth0` with your network interface name (e.g., `ens33`, `enp0s3`)

### 2. Create Macvlan Interface

After getting your host IP, create a macvlan interface to communicate with the container:

```bash
# Create a new macvlan interface
ip link add adguardhome-macvlan link eth0 type macvlan mode bridge

# Assign host's IP address to the macvlan interface with 32-bit mask
ip addr add 192.168.X.Z/32 dev adguardhome-macvlan

# Set the interface up
ip link set adguardhome-macvlan up

# Add a route to the container's subnet via adguardhome-macvlan
ip route add 192.168.X.Y/32 dev adguardhome-macvlan
```

### 3. Make Configuration Persistent

First, check which network tools are available on your system:

```bash
# Check if systemd-networkd is installed and running
systemctl status systemd-networkd

# Check if networkd-dispatcher is available
which networkd-dispatcher

# Check if netplan is being used
ls /etc/netplan/
```

Choose the appropriate configuration method based on your system:

#### Option A: Using systemd-networkd with cloud-init

Since the main network interface (eth0) is already configured by cloud-init through netplan, we only need to configure the macvlan interface using systemd-networkd:

1. Create parent interface configuration:
```bash
sudo mkdir -p /etc/systemd/network
sudo nano /etc/systemd/network/80-parent.network
```

```ini
[Match]
# Main interface configured by cloud-init
Name=eth0  

[Network]
MACVLAN=adguardhome-macvlan
```

2. Create macvlan interface definition:
```bash
sudo nano /etc/systemd/network/80-adguardhome-macvlan.netdev
```

```ini
[NetDev]
Name=adguardhome-macvlan
Kind=macvlan

[MACVLAN]
Mode=bridge
```

3. Create macvlan interface configuration:
```bash
sudo nano /etc/systemd/network/80-adguardhome-macvlan.network
```

```ini
[Match]
Name=adguardhome-macvlan

[Network]
# Host IP
Address=192.168.X.Z/32  

[Route]
# Container IP
Destination=192.168.X.Y/32  
Scope=link
```

4. Apply configuration:
```bash
sudo systemctl restart systemd-networkd
```

Benefits:
- Works seamlessly with cloud-init network configuration
- No modification to existing netplan configuration needed
- Configuration persists across reboots
- Clean separation of cloud-init and custom network configurations

#### Option B: Using systemd service

For systems that don't use systemd-networkd or when you prefer a service-based approach, you can use the provided systemd service. See the instructions in the [`docker-macvlan-setup`](./docker-macvlan-setup) directory for setting up automatic macvlan configuration using a custom systemd service.

Benefits:
- Works on any systemd-based system
- No dependency on specific network management tools
- Easy to configure through environment variables
- Automatic setup and cleanup
- Persists across reboots

#### Option C: Using networkd-dispatcher

For systems with networkd-dispatcher installed, this option provides dynamic interface configuration:

1. Install networkd-dispatcher:
```bash
sudo apt install networkd-dispatcher
```

2. Create macvlan setup script:
```bash
sudo mkdir -p /etc/networkd-dispatcher/routable.d/
sudo nano /etc/networkd-dispatcher/routable.d/50-adguardhome-macvlan
```

```bash
#!/bin/sh
PARENT_IF="$1"  # Network interface that triggered this script
IFACE="adguardhome-macvlan"

# Create macvlan interface if it doesn't exist
if ! ip link show "$IFACE" >/dev/null 2>&1; then
    ip link add "$IFACE" link "$PARENT_IF" type macvlan mode bridge
    ip addr add 192.168.X.Z/32 dev "$IFACE"  # Host IP
    ip link set "$IFACE" up
    ip route add 192.168.X.Y/32 dev "$IFACE"  # Container IP
fi
```

3. Make the script executable:
```bash
sudo chmod +x /etc/networkd-dispatcher/routable.d/50-adguardhome-macvlan
```

Benefits:
- Automatically creates macvlan when parent interface becomes available
- Works with dynamic network interfaces
- No need to specify parent interface in configuration
- Handles network interface changes automatically

Choose the method that best matches your system's configuration and requirements:
- Option A (systemd-networkd): Best for systems using cloud-init/netplan
- Option B (systemd service): Best for systems without specific network management tools
- Option C (networkd-dispatcher): Best for systems with dynamic network configurations

## Verify Configuration

Test the connection:
```bash
# From host to container
ping 192.168.X.Y  # Container IP

# From container to host (exec into container first)
docker exec -it adguardhome ping 192.168.X.Z  # Host IP
```

## Notes

- Internal network (`dns`) is isolated and used only for AdGuard Home and Unbound communication
- External network (`adguardhome-macvlan`) uses a single IP for AdGuard Home
- Host-container communication requires additional network configuration
- No port forwarding or masquerading needed
- Tailscale integration provides additional VPN capabilities
- Both configurations include Unbound as upstream DNS resolver

## Setup Instructions

1. Choose your preferred compose file:
   - `docker-compose.yaml` for basic setup
   - `tailscale-compose.yaml` for Tailscale integration

2. Configure the networks:
   1. Set your network interface name for macvlan (`parent: eth0`)
   2. Update subnet and gateway to match your network
   3. Set an available IP address for AdGuard Home

3. Start the services:
```bash
# For basic setup
docker-compose up -d

# For Tailscale setup
docker-compose -f tailscale-compose.yaml up -d
```

## References
- [Docker Bridge Network](https://docs.docker.com/engine/network/drivers/bridge/)
- [Docker Macvlan Network](https://docs.docker.com/network/drivers/macvlan/)
- [Docker Internal Networks](https://docs.docker.com/engine/reference/commandline/network_create/#internal)
- [Docker IPAM Options](https://docs.docker.com/engine/reference/commandline/network_create/#ipam)
- [Raspberry Pi Docker Macvlan Setup](https://github.com/novaspirit/pi-hosted/blob/master/docs/macvlan_setup.md)
- [Using Docker Macvlan Networks](https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/)
- [Linux Network Interfaces](https://wiki.archlinux.org/title/Network_configuration#Network_interfaces)
- [Arch Linux systemd-networkd](https://wiki.archlinux.org/title/Systemd-networkd)
- [netplan macvlan bug report](https://bugs.launchpad.net/netplan/+bug/1664847)