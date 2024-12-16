#!/bin/bash

# Configuration
HEALTHCHECKS_URL="https://healthchesks.yourdomain"
HEALTHCHECKS_UUID="your-healthchecks-uuid"
MOUNT_POINTS=(
    "/mnt/external"    # Change or add your mount points here
    "/mnt/backup"      # Example additional mount point

)
# Initialize error flag and failed mounts array
declare -a failed_mounts=()
exit_code=0
log=""

# Function to check a single mount point
check_mount_point() {
    local mount_point="$1"
    local error=0

    # Check if the mount point exists
    if [ ! -d "$mount_point" ]; then
        echo "Error: Mount point $mount_point does not exist"
        failed_mounts+=("$mount_point (directory not found)")
        error=1
    # Check if the mount point is mounted using findmnt
    elif ! findmnt -T "$mount_point" >/dev/null 2>&1; then
        echo "Error: $mount_point is not mounted"
        failed_mounts+=("$mount_point (not mounted)")
        error=1
    else
        echo "Info: Storage is mounted at $mount_point"
    fi

    return $error
}

if [ -n "$HEALTHCHECKS_UUID" ] && [ -n "$HEALTHCHECKS_URL" ]; then
    printf "Starting Healthchecks ping: "
    curl -m 10 --retry 5 "$HEALTHCHECKS_URL/ping/$HEALTHCHECKS_UUID/start"
    printf '\n'
fi

# Check all mount points
for mount_point in "${MOUNT_POINTS[@]}"; do
    if ! check_mount_point "$mount_point"; then
        exit_code=1
    fi
done

# Return final result with specific failures
if [ $exit_code -eq 1 ]; then
    log="Failure: The following mount points have issues:"
    log+=$(printf '\n%s' "${failed_mounts[@]}")
else
    log="Success: All mount points are properly mounted"
fi

if [ -n "$HEALTHCHECKS_UUID" ] && [ -n "$HEALTHCHECKS_URL" ]; then
    printf "Result from Healthchecks: "
    if [ $exit_code -eq 1 ]; then
        curl -fsS -m 10 --retry 5 --data-raw "$log" "$HEALTHCHECKS_URL/ping/$HEALTHCHECKS_UUID/$exit_code"
    else
        curl -m 10 --retry 5 "$HEALTHCHECKS_URL/ping/$HEALTHCHECKS_UUID/$exit_code"
    fi
    printf '\n'
fi

echo "$log"
exit $exit_code