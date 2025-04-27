#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration
CONTAINER_NAME="nextcloud"
LOG_FILE="/var/log/docker-nextcloud-cron.log"
exit_code=0
log=""

# Logging function
log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Check if container exists and is running
check_container() {
    log_message "INFO: Checking Nextcloud container status"
    if ! docker ps -q -f name="^/${CONTAINER_NAME}$"; then
        return 1
    fi
    return 0
}

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_message "INFO: Starting Nextcloud container cron job"
    
    # Check container status
    if ! check_container; then
        exit_code=1
        log="ERROR: Nextcloud container '${CONTAINER_NAME}' is not running"
        exit "$exit_code"
    fi
    
    # Run cron job
    if ! docker exec -u www-data "$CONTAINER_NAME" php /var/www/html/cron.php; then
        exit_code=1
        log="ERROR: Nextcloud container's cron job execution failed"
    fi
    
    log_message "INFO: Nextcloud container's cron job completed successfully"
    
    # Output final log message
    [ -n "$log" ] && log_message "$log"
    exit "$exit_code"
}

main "$@"