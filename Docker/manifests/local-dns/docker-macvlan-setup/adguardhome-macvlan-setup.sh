#!/bin/bash

# Check required environment variables
for var in INTERFACE HOST_IP CONTAINER_IP MACVLAN_INTERFACE; do
    if [ -z "${!var}" ]; then
        echo "ERROR: Required environment variable $var is not set"
        exit 1
    fi
done

# Check if network interface exists
if ! ip link show "${INTERFACE}" &>/dev/null; then
    echo "ERROR: Network interface ${INTERFACE} does not exist"
    exit 1
fi

# Create macvlan interface if it doesn't exist
if ! ip link show "${MACVLAN_INTERFACE}" &>/dev/null; then
    echo "INFO: Creating macvlan interface ${MACVLAN_INTERFACE}"
    ip link add "${MACVLAN_INTERFACE}" link "${INTERFACE}" type macvlan mode bridge
else
    echo "INFO: Macvlan interface ${MACVLAN_INTERFACE} already exists"
fi

# Check if IP is already assigned
if ! ip addr show dev "${MACVLAN_INTERFACE}" | grep -q "${HOST_IP}/32"; then
    echo "INFO: Assigning IP ${HOST_IP} to ${MACVLAN_INTERFACE}"
    ip addr add "${HOST_IP}/32" dev "${MACVLAN_INTERFACE}"
else
    echo "INFO: IP ${HOST_IP} already assigned to ${MACVLAN_INTERFACE}"
fi

# Set the interface up if it's down
if ip link show "${MACVLAN_INTERFACE}" | grep -q "state DOWN"; then
    echo "INFO: Setting interface ${MACVLAN_INTERFACE} up"
    ip link set "${MACVLAN_INTERFACE}" up
else
    echo "INFO: Interface ${MACVLAN_INTERFACE} is already up"
fi

# Add route to container subnet if it doesn't exist
if ! ip route show | grep -q "${CONTAINER_IP}.*dev ${MACVLAN_INTERFACE}"; then
    echo "INFO: Adding route to ${CONTAINER_IP} via ${MACVLAN_INTERFACE}"
    ip route add "${CONTAINER_IP}/32" dev "${MACVLAN_INTERFACE}"
else
    echo "INFO: Route to ${CONTAINER_IP} via ${MACVLAN_INTERFACE} already exists"
fi
