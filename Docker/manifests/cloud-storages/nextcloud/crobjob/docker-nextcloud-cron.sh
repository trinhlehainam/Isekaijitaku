#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration
HEALTHCHECKS_BASE_URL="https://healthchecks.yourdomain"
HEALTHCHECKS_UUID=""
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
    if ! docker ps -q -f name="^/${CONTAINER_NAME}$"; then
        return 1
    fi
    return 0
}

# Healthchecks ping function
send_healthcheck() {
    local status=$1
    local message="${2:-}"
    if [ -n "$HEALTHCHECKS_UUID" ] && [ -n "$HEALTHCHECKS_BASE_URL" ]; then
        if [ "$status" = "start" ]; then
            log_message "Starting Healthchecks ping"
            curl -m 10 --retry 5 "$HEALTHCHECKS_BASE_URL/ping/$HEALTHCHECKS_UUID/start" || log_message "WARNING: Failed to send start ping"
        else
            log_message "Sending result to Healthchecks"
            if [ -n "$message" ]; then
                curl -fsS -m 10 --retry 5 --data-raw "$message" "$HEALTHCHECKS_BASE_URL/ping/$HEALTHCHECKS_UUID/$exit_code" || log_message "WARNING: Failed to send result ping"
            else
                curl -m 10 --retry 5 "$HEALTHCHECKS_BASE_URL/ping/$HEALTHCHECKS_UUID/$exit_code" || log_message "WARNING: Failed to send result ping"
            fi
        fi
    fi
}

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_message "Starting Nextcloud cron job"
    
    # Send start ping to Healthchecks
    send_healthcheck "start"
    
    # Check container status
    if ! check_container; then
        exit_code=1
        log="ERROR: Nextcloud container '${CONTAINER_NAME}' is not running"
        send_healthcheck "$exit_code" "$log"
        exit "$exit_code"
    fi
    
    # Run cron job
    if ! docker exec -u www-data "$CONTAINER_NAME" php /var/www/html/cron.php; then
        exit_code=1
        log="ERROR: Nextcloud container's cron job execution failed"
    fi
    
    log_message "INFO: Nextcloud container's cron job completed successfully"

    # Send result to Healthchecks
    send_healthcheck "$exit_code" "$log"
    
    # Output final log message
    [ -n "$log" ] && log_message "$log"
    exit "$exit_code"
}

main "$@"