#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration
HEALTHCHECKS_BASE_URL="https://healthchecks.yourdomain"
HEALTHCHECKS_UUID=""
# Define external drives to check
EXTERNAL_DRIVES=(
    "/dev/sdb1:/mnt/external"    # Format: device:mountpoint
    "/dev/sdc1:/mnt/backup"      # Example additional drive
)
LOG_FILE="/var/log/check-external-drives-mounted.log"
# Initialize error flag and failed mounts array
declare -a failed_mounts=()
exit_code=0
log=""

# Logging function
log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to check a single mount point
check_mount_point() {
    local device="$1"
    local mount_point="$2"
    local error=0

    # Check if the mount point exists
    if [ ! -d "$mount_point" ]; then
        echo "ERROR: Mount point $mount_point does not exist"
        failed_mounts+=("$mount_point (directory not found)")
        error=1
        return $error
    fi

    # Check if device exists
    if [ ! -b "$device" ]; then
        echo "ERROR: Device $device not found"
        failed_mounts+=("$device (device not found)")
        error=1
        return $error
    fi

    # Check if the device is mounted at the correct point
    if ! findmnt -S "$device" -T "$mount_point" >/dev/null 2>&1; then
        echo "ERROR: $device is not mounted at $mount_point"
        failed_mounts+=("$device (not mounted at $mount_point)")
        error=1
    else
        # Get drive details
        local size
        local used
        local avail
        eval "$(df -h "$mount_point" | awk 'NR==2 {printf "size=%s;used=%s;avail=%s", $2, $3, $4}')"
        echo "INFO: External drive mounted at $mount_point"
        echo "      Total: $size, Used: $used, Available: $avail"
        
        # Check drive health if possible
        if command -v smartctl >/dev/null 2>&1; then
            if smartctl -H "$device" >/dev/null 2>&1; then
                echo "      Drive health check passed"
            else
                echo "WARNING: Drive health check failed for $device"
                error=1
            fi
        fi
    fi

    return $error
}

# Healthchecks ping function
send_healthcheck() {
    local status=$1
    local message="${2:-}"
    if [ -n "$HEALTHCHECKS_UUID" ] && [ -n "$HEALTHCHECKS_BASE_URL" ]; then
        if [ "$status" = "start" ]; then
            log_message "INFO: Starting Healthchecks ping"
            curl -fsS -m 10 --retry 5 -o /dev/null "$HEALTHCHECKS_BASE_URL/ping/$HEALTHCHECKS_UUID/start" || log_message "WARNING: Failed to send start ping"
        else
            log_message "INFO: Sending result to Healthchecks"
            if [ -n "$message" ]; then
                curl -fsS -m 10 --retry 5 -o /dev/null --data-raw "$message" "$HEALTHCHECKS_BASE_URL/ping/$HEALTHCHECKS_UUID/$status" || log_message "WARNING: Failed to send result ping"
            else
                curl -fsS -m 10 --retry 5 -o /dev/null "$HEALTHCHECKS_BASE_URL/ping/$HEALTHCHECKS_UUID/$status" || log_message "WARNING: Failed to send result ping"
            fi
        fi
    fi
}

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_message "INFO: Starting external drive mount check"
    
    # Send start ping to Healthchecks
    send_healthcheck "start"
    
    # Check all external drives
    for drive_info in "${EXTERNAL_DRIVES[@]}"; do
        IFS=':' read -r device mount_point <<< "$drive_info"
        if ! check_mount_point "$device" "$mount_point"; then
            exit_code=1
        fi
    done

    if [ $exit_code -eq 1 ]; then
        log="FAIL: Issues found with external drive mounts:"
        log+=$(printf '\n%s' "${failed_mounts[@]}")
    else
        log="SUCCESS: All external drives are properly mounted"
    fi

    # Send result to Healthchecks
    send_healthcheck "$exit_code" "$log"
    
    # Output final log message
    [ -n "$log" ] && log_message "$log"
    exit "$exit_code"
}

main "$@"
