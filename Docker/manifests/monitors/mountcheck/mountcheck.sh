#!/usr/bin/env bash

# Script to continuously check if multiple mount points are properly mounted
# Exit codes:
# 0 - All mount points are properly mounted
# 1 - One or more mount points are not mounted or .mount files missing

MOUNT_PATH="/mnt"
CHECK_INTERVAL=10  # Check every 10 seconds
RETRIES=3

# Function to check a single mount point
check_single_mount() {
    local mount_point="$1"
    local mount_file="$mount_point/.mounted"
    
    if [ ! -f "$mount_file" ]; then
        echo "ERROR: Mount point check failed - .mounted file not found at $mount_file"
        return 1
    fi
    echo "INFO: Mount point check passed - .mounted file found at $mount_file"
    return 0
}

# Function to check all mount points
check_all_mounts() {
    local return_code=0
    
    # Find all mount points (directories) under MOUNT_PATH
    for mount_point in "$MOUNT_PATH"/*; do
        if [ -d "$mount_point" ]; then
            echo "INFO: Checking mount point: $mount_point"
            if ! check_single_mount "$mount_point"; then
                return_code=1
            fi
        fi
    done
    
    return $return_code
}

# SIGTERM-handler
term_handler() {
    exit 143  # 128 + 15 -- SIGTERM
}

trap 'kill $$; term_handler' SIGTERM

# Main loop
while true && [ $RETRIES -gt 0 ]; do
    if ! check_all_mounts; then
        RETRIES=$((RETRIES - 1))
    fi
    if [ $RETRIES -eq 0 ]; then
        exit 1
    fi
    sleep $CHECK_INTERVAL
done
