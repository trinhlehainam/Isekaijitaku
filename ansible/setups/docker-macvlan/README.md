---
aliases:
  - "Setup Docker macvlan network on Linux"
Title: Setup Docker macvlan network on Linux
Creation Date: 2025-05-07 4:46
tags:
  - permanent
  - linux
  - docker
  - macvlan
  - network
  - ansible
  - host-communication
  - tutorial
---

This guide explains configuring Docker macvlan networks on Linux, allowing containers to have unique LAN IPs, and how to enable communication between the Docker host and these macvlan containers using an Ansible role.

## 1. Prerequisites

- Linux system with Docker installed.
- Root/sudo access.
- LAN configuration details: router IP (gateway), DHCP range.
- Host's LAN network interface name (e.g., `eth0`).
- Ansible installed on the control node if using the provided Ansible role.

**Raspberry Pi:** If `Error ... operation not supported` occurs, install extra kernel modules:
```sh
sudo apt update && sudo apt install -y linux-modules-extra-raspi && sudo reboot
```

## 2. Planning Macvlan Network

Avoid IP conflicts by careful planning.

- **LAN CIDR**: Find with `ip a` (e.g., `192.168.1.0/24`).
- **Router DHCP Range**: Check router settings (e.g., `192.168.1.100-192.168.1.200`).
- **Macvlan Container IP Range**: Choose a range within your LAN's subnet but *outside* the DHCP range and any static IPs (e.g., `192.168.1.210/28` for IPs `192.168.1.210-192.168.1.222`). If you have a specific start and end IP for your container range, you can use an online tool like [ip2cidr.com](https://ip2cidr.com/) (see References) to convert this range into the required CIDR notation (e.g., `192.168.1.210-192.168.1.222` becomes `192.168.1.210/28`).

Key parameters for Docker macvlan network creation:
- **Subnet**: Your LAN's subnet (e.g., `192.168.1.0/24`).
- **Gateway**: Your router's IP (e.g., `192.168.1.1`).
- **IP Range**: The chosen range for containers (e.g., `192.168.1.210/28`).

## 3. Creating Docker Macvlan Network

This step involves creating the Docker network itself. Containers will be attached to this network.

### Method 1: Docker CLI

```sh
MY_PARENT_INTERFACE="eth0"
MY_MACVLAN_NETWORK_NAME="mypublicnet"
MY_NETWORK_SUBNET="192.168.1.0/24"
MY_NETWORK_GATEWAY="192.168.1.1"
MY_MACVLAN_IP_RANGE="192.168.1.210/28"

docker network create -d macvlan \
  --subnet=${MY_NETWORK_SUBNET} \
  --gateway=${MY_NETWORK_GATEWAY} \
  --ip-range=${MY_MACVLAN_IP_RANGE} \
  -o parent=${MY_PARENT_INTERFACE} \
  ${MY_MACVLAN_NETWORK_NAME}
```
Verify: `docker network inspect ${MY_MACVLAN_NETWORK_NAME}`.

### Method 2: Docker Compose

Define in `docker-compose.yml`:
```yaml
version: '3.8'
services:
  my_app:
    image: some_image
    networks:
      macvlan_net:
        ipv4_address: 192.168.1.210 # Static IP from macvlan_net IP range
networks:
  macvlan_net:
    driver: macvlan
    driver_opts:
      parent: eth0 # Your parent interface
    ipam:
      config:
        - subnet: 192.168.1.0/24
          gateway: 192.168.1.1
          ip_range: 192.168.1.210/28
```
To use a pre-existing CLI-created network: 
```yaml
networks:
  macvlan_net:
    external:
      name: mypublicnet
```

## 4. Enabling Host-Container Communication via Ansible

By default, the Docker host cannot communicate directly with containers on a macvlan network because the traffic bypasses the host's network stack. To enable this communication, a separate macvlan interface must be created on the host itself, assigned an IP from the same LAN subnet (but outside the Docker macvlan network's IP range and DHCP range), and routes must be added for the container IPs/subnets via this new host macvlan interface.

This Ansible role automates the creation, configuration, and persistent management of these host-side macvlan interfaces using systemd.

### Role Overview

The `setup-docker-macvlan` Ansible role performs the following actions:
1.  Copies `docker-macvlans-setup.sh` and `docker-macvlans-cleanup.sh` scripts to `/usr/local/bin/` on the target host.
2.  Copies a `docker-macvlans.service` systemd unit file to `/etc/systemd/system/`.
3.  Creates a configuration directory `/etc/docker-macvlan.d/`.
4.  Generates individual `*.conf` files within `/etc/docker-macvlan.d/` based on the `docker_macvlan_setups` variable provided in your Ansible inventory or playbook variables. Each `.conf` file defines one host-side macvlan interface and its associated container routes.
5.  Reloads the systemd daemon, enables, and starts the `docker-macvlans.service`.

The systemd service uses the scripts to set up the host macvlan interfaces on boot (and when the service starts) and clean them up on shutdown (and when the service stops).

### Configuration

To use this Ansible role, you need to define the `docker_macvlan_setups` variable. This variable is a list of dictionaries, where each dictionary specifies the configuration for one host-side macvlan interface.

Each dictionary in the `docker_macvlan_setups` list must contain the following keys:

-   `file_name` (string): A descriptive name for this macvlan setup. This will be used as the name of the `.conf` file generated in `/etc/docker-macvlan.d/`. Example: `"public_access"` would create `public_access.conf`.
-   `parent_interface` (string): The name of the host's physical network interface to which this macvlan interface will be linked (e.g., `"eth0"`, `"enp3s0"`).
-   `host_ip` (string): The static IP address to assign to this new host-side macvlan interface. This IP **must** be on the same LAN subnet as your `parent_interface` and **must not** conflict with your router, DHCP range, or any IPs used by your Docker macvlan containers. The setup script will automatically append `/32` to this IP. Example: `"192.168.1.200"`.
-   `macvlan_interface_name` (string): The desired name for the new macvlan interface that will be created on the host (e.g., `"macvlan-host0"`, `"br-public"`).
-   `container_cidrs` (list of strings): A list of IP CIDR blocks. These CIDRs represent the IPs or subnets of your Docker containers running on the corresponding Docker macvlan network. The setup script will add routes for each of these CIDRs pointing to the `macvlan_interface_name`. This enables the host to reach the containers. Example: `["192.168.1.210/32", "192.168.1.215/32"]` or `["192.168.1.208/28"]` if your Docker macvlan network `ip-range` is `192.168.1.208/28`.

#### Example Ansible Variable Definition (`inventory/group_vars/all.yml` or similar):

```yaml
docker_macvlan_setups:
  - file_name: "public_network_host_if"
    parent_interface: "eth0"
    host_ip: "192.168.1.209"  # IP for the host's macvlan interface
    macvlan_interface_name: "macvlan-public-host"
    container_cidrs:
      - "192.168.1.210/28"   # CIDR of your 'mypublicnet' Docker macvlan network
      # Add more container CIDRs if you have multiple Docker macvlan networks or specific container IPs to route

  # You can define multiple host-side macvlan interfaces if needed, for example, for different physical networks
  # - file_name: "iot_network_host_if"
  #   parent_interface: "eth1"
  #   host_ip: "192.168.2.209"
  #   macvlan_interface_name: "macvlan-iot-host"
  #   container_cidrs:
  #     - "192.168.2.100/28"
```

### How it Works Internally

For each item in `docker_macvlan_setups`, the Ansible role generates a configuration file in `/etc/docker-macvlan.d/`. For instance, for the `public_network_host_if` example above, a file named `public_network_host_if.conf` would be created with content similar to:

```ini
# Configuration for Docker macvlan host interface: public_network_host_if
# Generated by Ansible

INTERFACE="eth0"
HOST_IP="192.168.1.209"
MACVLAN_INTERFACE="macvlan-public-host"
CONTAINER_IP_CIDR=("192.168.1.210/28" )
```

The `docker-macvlans-setup.sh` script, when run by systemd, reads each `.conf` file in `/etc/docker-macvlan.d/`. For each configuration, it:
1.  Checks if the parent interface is up.
2.  Creates the macvlan interface (`macvlan-public-host` in the example) linked to the parent interface (`eth0`).
3.  Assigns the specified `HOST_IP` (`192.168.1.209/32`) to this new host macvlan interface.
4.  Brings up the new host macvlan interface.
5.  Adds routes for each CIDR in `CONTAINER_IP_CIDR` (e.g., `192.168.1.210/28`) via the new host macvlan interface.

The `docker-macvlans-cleanup.sh` script, run by systemd on stop, iterates through the same `.conf` files and deletes the host macvlan interfaces (`macvlan-public-host`), which also removes associated routes.

## 5. Testing Host-Container Communication

After the Ansible role has run and the `docker-macvlans.service` is active:

1.  **From Host to Container:** Ping a container's macvlan IP from the Docker host.
    ```sh
    ping 192.168.1.210 # (Use an IP from your container_cidrs range)
    ```
2.  **From Container to Host:** If your container image has `iproute2` or similar, you can exec into the container and ping the host's new macvlan interface IP (`host_ip` defined in your Ansible vars, e.g., `192.168.1.209`). You can also ping the host's main IP on `eth0` or your gateway.
    ```sh
    docker exec -it <your_container_name_or_id> ping 192.168.1.209
    ```

## Troubleshooting

-   **Check Service Status:** `sudo systemctl status docker-macvlans.service`
-   **View Logs:** `sudo journalctl -u docker-macvlans.service -n 100 --no-pager` (The Ansible role also displays recent logs at the end of its run).
-   **Verify Host Interfaces:** `ip addr show` (look for your `macvlan_interface_name` and its IP).
-   **Verify Host Routes:** `ip route show` (look for routes to your `container_cidrs` via your `macvlan_interface_name`).
-   Ensure `CONFIG_PATH=/etc/docker-macvlan.d` is correctly set in the `docker-macvlans.service` file if you deviate from the role's defaults.
-   Ensure the IP addresses chosen for `host_ip` are unique and not used by any other device or container on your network and are outside your DHCP server's scope.
-   Ensure `container_cidrs` accurately reflect the IP addresses or ranges used by your containers on their respective Docker macvlan networks.

## References

- [pi-hosted macvlan_setup.md](https://github.com/novaspirit/pi-hosted/blob/master/docs/macvlan_setup.md)
- [Using Docker Macvlan Networks](https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/)
- [ip2cidr.com - Online IP to CIDR Converter](https://ip2cidr.com/)
- [Docker Macvlan Networking Tutorial](https://docs.docker.com/engine/network/tutorials/macvlan/)
- [Docker Macvlan Network Driver](https://docs.docker.com/engine/network/drivers/macvlan/)
- [Understand IP Addresses, Subnets, and CIDR Notation for Networking](https://www.digitalocean.com/community/tutorials/understanding-ip-addresses-subnets-and-cidr-notation-for-networking)
- [Arch Linux systemd-networkd](https://wiki.archlinux.org/title/Systemd-networkd)