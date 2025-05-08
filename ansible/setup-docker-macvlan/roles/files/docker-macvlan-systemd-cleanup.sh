#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Helper function to clean up a single macvlan configuration ---
# Arguments:
#   $1: Name of the macvlan interface to clean up
#   $2: Name of the CONTAINER_IP_CIDR array (for nameref)
_cleanup_one_macvlan() {
    local macvlan_if_name="$1"
    local -n cidrs_array_ref="$2" # Nameref to the CONTAINER_IP_CIDR array from the sourced .conf file

    echo "INFO [${macvlan_if_name} CLEANUP]: Cleaning up..."

    # 1. Remove routes for container CIDRs for this specific macvlan
    if [ ${#cidrs_array_ref[@]} -gt 0 ]; then
        echo "INFO [${macvlan_if_name} CLEANUP]: Processing ${#cidrs_array_ref[@]} CIDR(s) for route removal: ${cidrs_array_ref[*]}"
        for cidr_to_route in "${cidrs_array_ref[@]}"; do
            if [ -z "${cidr_to_route}" ]; then continue; fi
            # Check if route exists before attempting to delete
            if ip route show | grep -q "${cidr_to_route}[[:space:]]dev[[:space:]]${macvlan_if_name}"; then
                echo "INFO [${macvlan_if_name} CLEANUP]: Removing route for ${cidr_to_route}..."
                ip route del "${cidr_to_route}" dev "${macvlan_if_name}"
            else
                echo "INFO [${macvlan_if_name} CLEANUP]: Route for ${cidr_to_route} does not exist or already removed."
            fi
        done
    else
        echo "INFO [${macvlan_if_name} CLEANUP]: No container CIDRs defined for this entry. Skipping route removal."
    fi

    # 2. Delete the macvlan interface if it exists
    if ip link show "${macvlan_if_name}" > /dev/null 2>&1; then
        echo "INFO [${macvlan_if_name} CLEANUP]: Setting down and deleting interface..."
        ip link set "${macvlan_if_name}" down
        ip link delete "${macvlan_if_name}"
    else
        echo "INFO [${macvlan_if_name} CLEANUP]: Interface does not exist. Nothing to delete."
    fi

    echo "INFO [${macvlan_if_name} CLEANUP]: Cleanup complete."
    return 0 # Success for this specific configuration
}

# --- Main Script Logic (Cleanup) ---
echo "--- Docker Macvlan Systemd Cleanup Script Starting ---"

if [ -z "${CONFIG_PATH}" ] || [ ! -d "${CONFIG_PATH}" ]; then
    echo "ERROR: CONFIG_PATH environment variable not set or is not a valid directory: '${CONFIG_PATH}'" >&2
    exit 1 # Critical error, service should fail
fi

processed_files=0
successful_cleanups=0

shopt -s nullglob # Ensure loop doesn't run if no files match
for conf_file in "${CONFIG_PATH}"/*.conf; do
    processed_files=$((processed_files + 1))
    echo "--- Processing configuration file for cleanup: ${conf_file} ---"

    # Reset variables for each file
    MACVLAN_INTERFACE=""
    unset CONTAINER_IP_CIDR
    declare -a CONTAINER_IP_CIDR=() # Bash array

    # Source the configuration file
    # shellcheck source=/dev/null
    . "${conf_file}"

    # Validate MACVLAN_INTERFACE from the current file
    if [ -z "${MACVLAN_INTERFACE}" ]; then
        echo "WARNING [${conf_file}]: MACVLAN_INTERFACE not defined. Skipping this file for cleanup." >&2
        continue # Move to the next configuration file
    fi

    # Validate CONTAINER_IP_CIDR declaration from the current file
    if ! declare -p CONTAINER_IP_CIDR &>/dev/null || [[ "$(declare -p CONTAINER_IP_CIDR)" != "declare -a "* ]]; then 
        echo "WARNING [${conf_file}]: CONTAINER_IP_CIDR is not declared as an array. Cleanup of routes might be incomplete for this entry, but proceeding with interface cleanup." >&2
        # If CIDR is malformed, we will still try to clean up the interface by name, but route cleanup for this file might be skipped or partial.
        # The _cleanup_one_macvlan function will attempt to use the (potentially malformed) array.
    fi

    # Call the cleanup function for this specific configuration
    # Pass MACVLAN_INTERFACE and the NAME of CONTAINER_IP_CIDR for nameref
    if _cleanup_one_macvlan "${MACVLAN_INTERFACE}" CONTAINER_IP_CIDR; then
        successful_cleanups=$((successful_cleanups + 1))
    else
        echo "ERROR [${conf_file}]: Failed to cleanup macvlan defined in this file. Check logs above." >&2
    fi
done
shopt -u nullglob # Revert nullglob option

if [ ${processed_files} -eq 0 ]; then
    echo "WARNING: No *.conf files found in ${CONFIG_PATH}. Nothing to clean up." >&2
    exit 0
fi

echo "--- Summary: ${successful_cleanups} out of ${processed_files} configurations cleaned up successfully. ---"

if [ ${successful_cleanups} -lt ${processed_files} ]; then
    echo "WARNING: Some macvlan configurations failed to clean up. Check logs above." >&2
fi

exit 0 # Script completed its run.