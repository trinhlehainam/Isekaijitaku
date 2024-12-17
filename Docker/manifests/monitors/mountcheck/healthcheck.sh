#!/usr/bin/env bash

# Script to check mount points once and return immediately
# Exit codes:
# 0 - All mount points are properly mounted
# 1 - One or more mount points are not mounted or .mount files missing

MOUNT_PATH="/mnt"

# Function to check a single mount point
check_single_mount() {
    local mount_point="$1"
    local mount_file="$mount_point/.mounted"
    
    if [ ! -f "$mount_file" ]; then
        echo "ERROR: Mount point check failed - .mount file not found at $mount_file"
        return 1
    fi
    return 0
}

# Function to check all mount points
check_all_mounts() {
    local return_code=0
    
    # Find all mount points (directories) under MOUNT_PATH
    for mount_point in "$MOUNT_PATH"/*; do
        if [ -d "$mount_point" ]; then
            if ! check_single_mount "$mount_point"; then
                return_code=1
            fi
        fi
    done
    
    return $return_code
}

# Run once and exit
check_all_mounts
exit $?
