#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Helper function to set up a single macvlan configuration ---
# Arguments:
#   $1: Parent interface name (e.g., eth0)
#   $2: Host IP address for the macvlan interface (e.g., 192.168.1.209)
#   $3: Desired name for the macvlan interface (e.g., mypublicnet-host)
#   $4: Name of the CONTAINER_IP_CIDR array (for nameref)
_setup_one_macvlan() {
    local parent_if="$1"
    local host_ip_addr="$2"
    local macvlan_if_name="$3"
    local -n cidrs_array_ref="$4" # Nameref to the CONTAINER_IP_CIDR array from the sourced .conf file

    echo "INFO [${macvlan_if_name} SETUP]: Validating operational parameters for parent '${parent_if}' with IP '${host_ip_addr}'..."

    # 1. Check parent interface status (operational check)
    if ! ip link show "${parent_if}" up > /dev/null 2>&1; then 
        echo "ERROR [${macvlan_if_name} SETUP]: Parent interface '${parent_if}' is not up or does not exist. Aborting for this entry." >&2
        return 1 # Failure for this specific configuration
    fi

    # 2. Create macvlan interface if it doesn't exist
    if ! ip link show "${macvlan_if_name}" > /dev/null 2>&1; then
        echo "INFO [${macvlan_if_name} SETUP]: Creating macvlan interface..."
        ip link add "${macvlan_if_name}" link "${parent_if}" type macvlan mode bridge
    else
        echo "INFO [${macvlan_if_name} SETUP]: Macvlan interface already exists."
    fi

    # 3. Assign IP address to macvlan interface if not already assigned
    if ! ip addr show "${macvlan_if_name}" | grep -q "${host_ip_addr}/"; then # Check with / to be more precise
        echo "INFO [${macvlan_if_name} SETUP]: Assigning IP ${host_ip_addr}/32..."
        ip addr add "${host_ip_addr}/32" dev "${macvlan_if_name}"
    fi

    # 4. Bring up the macvlan interface
    echo "INFO [${macvlan_if_name} SETUP]: Bringing up interface..."
    ip link set "${macvlan_if_name}" up

    # 5. Add routes for container CIDRs for this specific macvlan
    if [ ${#cidrs_array_ref[@]} -gt 0 ]; then
        echo "INFO [${macvlan_if_name} SETUP]: Processing ${#cidrs_array_ref[@]} CIDR(s) for route addition: ${cidrs_array_ref[*]}"
        for cidr_to_route in "${cidrs_array_ref[@]}"; do
            if [ -z "${cidr_to_route}" ]; then continue; fi
            if ip route show | grep -q "${cidr_to_route}[[:space:]]dev[[:space:]]${macvlan_if_name}"; then
                echo "INFO [${macvlan_if_name} SETUP]: Route for ${cidr_to_route} via ${macvlan_if_name} already exists."
                continue;
            fi
            echo "INFO [${macvlan_if_name} SETUP]: Adding route for ${cidr_to_route}..."
            if ! ip route add "${cidr_to_route}" dev "${macvlan_if_name}"; then
                echo "ERROR [${macvlan_if_name} SETUP]: Failed to add route for ${cidr_to_route} via ${macvlan_if_name}."
            fi
        done
    else
        echo "INFO [${macvlan_if_name} SETUP]: No container CIDRs defined for this entry. Skipping route addition."
    fi

    echo "INFO [${macvlan_if_name} SETUP]: Setup complete."
    return 0 # Success for this specific configuration
}

# --- Main Script Logic (Setup) ---
echo "--- Docker Macvlan Systemd Setup Script Starting ---"

if [ -z "${CONFIG_PATH}" ] || [ ! -d "${CONFIG_PATH}" ]; then
    echo "ERROR: CONFIG_PATH environment variable not set or is not a valid directory: '${CONFIG_PATH}'" >&2
    exit 1 # Critical error, service should fail
fi

processed_files=0
successful_setups=0

shopt -s nullglob # Ensure loop doesn't run if no files match
for conf_file in "${CONFIG_PATH}"/*.conf; do
    processed_files=$((processed_files + 1))
    echo "--- Processing configuration file: ${conf_file} ---"

    # Reset variables for each file to prevent leakage
    INTERFACE=""
    HOST_IP=""
    MACVLAN_INTERFACE=""
    unset CONTAINER_IP_CIDR
    declare -a CONTAINER_IP_CIDR=() # Bash array
    
    # Source the configuration file
    # shellcheck source=/dev/null
    . "${conf_file}"
    
    # Validate essential scalar variables from the current file
    if [ -z "${INTERFACE}" ] || [ -z "${HOST_IP}" ] || [ -z "${MACVLAN_INTERFACE}" ]; then
        echo "WARNING [${conf_file}]: Missing one or more essential variables (INTERFACE, HOST_IP, MACVLAN_INTERFACE). Skipping this file." >&2
        continue # Move to the next configuration file
    fi

    # Validate CONTAINER_IP_CIDR declaration from the current file
    if ! declare -p CONTAINER_IP_CIDR &>/dev/null || [[ "$(declare -p CONTAINER_IP_CIDR)" != "declare -a "* ]]; then 
        echo "WARNING [${conf_file}]: CONTAINER_IP_CIDR is not declared as an array. Skipping this file." >&2
        continue # Move to the next configuration file
    fi

    # Call the setup function for this specific configuration
    # Pass MACVLAN_INTERFACE, INTERFACE, HOST_IP, and the NAME of CONTAINER_IP_CIDR for nameref
    if _setup_one_macvlan "${INTERFACE}" "${HOST_IP}" "${MACVLAN_INTERFACE}" "CONTAINER_IP_CIDR"; then
        successful_setups=$((successful_setups + 1))
    else
        echo "ERROR [${conf_file}]: Failed to set up macvlan defined in this file. Check logs above." >&2
        # Individual config failures are logged but don't cause the script to exit with an error immediately
    fi
done
shopt -u nullglob # Revert nullglob option

if [ ${processed_files} -eq 0 ]; then
    echo "WARNING: No *.conf files found in ${CONFIG_PATH}. Nothing to configure." >&2
    # Depending on requirements, this could be exit 0 (success, nothing to do) or exit 1 (error, config missing)
    exit 0 
fi

echo "--- Summary: ${successful_setups} out of ${processed_files} configurations processed successfully. ---"

if [ ${successful_setups} -lt ${processed_files} ]; then
    echo "WARNING: Some macvlan configurations failed to set up. Check logs above." >&2
    # Exit with an error code if any setup failed, to alert systemd more actively if needed.
    # For now, consistent with previous behavior, we log warnings and exit 0 if script ran.
    # To make systemd mark service as failed on partial success: exit 1
fi

exit 0 # Script completed its run.
