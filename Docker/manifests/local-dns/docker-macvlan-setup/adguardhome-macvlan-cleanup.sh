#!/bin/bash

# Check required environment variables
for var in CONTAINER_IP MACVLAN_INTERFACE; do
    if [ -z "${!var}" ]; then
        echo "ERROR: Required environment variable $var is not set"
        exit 1
    fi
done

# Check if interface exists before attempting cleanup
if ip link show "${MACVLAN_INTERFACE}" &>/dev/null; then
    # Remove route if it exists
    if ip route show | grep -q "${CONTAINER_IP}.*dev ${MACVLAN_INTERFACE}"; then
        echo "INFO: Removing route to ${CONTAINER_IP} via ${MACVLAN_INTERFACE}"
        ip route del "${CONTAINER_IP}/32" dev "${MACVLAN_INTERFACE}"
    else
        echo "INFO: Route to ${CONTAINER_IP} via ${MACVLAN_INTERFACE} does not exist"
    fi

    # Remove interface
    echo "INFO: Removing interface ${MACVLAN_INTERFACE}"
    ip link del "${MACVLAN_INTERFACE}"
else
    echo "INFO: Interface ${MACVLAN_INTERFACE} does not exist"
fi
