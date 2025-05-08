#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Helper function to clean up a single macvlan configuration ---
# Arguments:
#   $1: Name of the macvlan interface to clean up
_cleanup_one_macvlan() {
    local macvlan_if_name="$1"

    echo "INFO [${macvlan_if_name} CLEANUP]: Cleaning up..."

    # Delete the macvlan interface if it exists
    if ip link show "${macvlan_if_name}" > /dev/null 2>&1; then
        echo "INFO [${macvlan_if_name} CLEANUP]: Deleting interface..."
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

    # Source the configuration file
    # shellcheck source=/dev/null
    . "${conf_file}"

    # Validate MACVLAN_INTERFACE from the current file
    if [ -z "${MACVLAN_INTERFACE}" ]; then
        echo "WARNING [${conf_file}]: MACVLAN_INTERFACE not defined. Skipping this file for cleanup." >&2
        continue # Move to the next configuration file
    fi

    # Call the cleanup function for this specific configuration
    if _cleanup_one_macvlan "${MACVLAN_INTERFACE}"; then
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