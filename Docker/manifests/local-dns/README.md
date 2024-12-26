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
        - subnet: 192.168.x.0/24  # Single IP for AdGuard Home
          gateway: 192.168.x.1     # Change to match your network gateway
          ip_range: 192.168.x.y/32  # Restrict to single IP
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
  --subnet 192.168.x.0/24 \
  --gateway 192.168.x.1 \
  --ip-range 192.168.x.y/32 \
  --aux-address="host=192.168.x.z" \
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
ip link add adguardhome-lan link eth0 type macvlan mode bridge

# Assign host's IP address to the macvlan interface with 32-bit mask
ip addr add 192.168.x.z/32 dev adguardhome-lan

# Set the interface up
ip link set adguardhome-lan up

# Add a route to the container's subnet via adguardhome-lan
ip route add 192.168.x.y/32 dev adguardhome-lan
```

### 3. Make Configuration Persistent

The recommended way to make the network configuration persistent is using `systemd-networkd`, which is the default network service on most modern Linux distributions:

1. Create network configuration file:
```bash
sudo mkdir -p /etc/systemd/network
sudo nano /etc/systemd/network/25-adguardhome.netdev
```

Add the following configuration:
```ini
[NetDev]
Name=adguardhome-lan
Kind=macvlan
MACAddress=

[MACVLAN]
Mode=bridge
Parent=eth0  # Change to your network interface
```

2. Create interface configuration:
```bash
sudo nano /etc/systemd/network/25-adguardhome.network
```

Add the following configuration:
```ini
[Match]
Name=adguardhome-lan

[Network]
Address=192.168.x.z/32  # Your host IP
Gateway=192.168.x.1     # Your network gateway

[Route]
Destination=192.168.x.y/32  # Container IP
Scope=link
```

3. Enable and restart systemd-networkd:
```bash
sudo systemctl enable systemd-networkd
sudo systemctl restart systemd-networkd
```

Alternative methods for systems not using systemd-networkd:

#### Option 1: Using systemd service

See the instructions in the [`docker-macvlan-setup`](./docker-macvlan-setup) directory for setting up automatic macvlan configuration using a custom systemd service.

#### Option 2: Using network configuration files (Legacy)

### 4. Verify Configuration

Test the connection:
```bash
# From host to container
ping 192.168.x.y  # Container IP

# From container to host (exec into container first)
docker exec -it adguardhome ping 192.168.x.z  # Host IP
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