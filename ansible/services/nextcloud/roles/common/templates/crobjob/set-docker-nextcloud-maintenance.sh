#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration
CONTAINER_NAME="nextcloud"

# Default values
TIME="${1:-04:00}"
TIMEZONE="${2:-Asia/Tokyo}"

# Function to print usage
print_usage() {
    echo "Usage: $0 [TIME] [TIMEZONE]"
    echo
    echo "Configure Nextcloud maintenance window time and timezone settings"
    echo
    echo "Arguments:"
    echo "  TIME     : Time in 24-hour format (HH:MM), default: 04:00"
    echo "  TIMEZONE : Timezone (e.g., Asia/Tokyo), default: Asia/Tokyo"
    echo
    echo "Options:"
    echo "  -h, --help     : Show this help message"
    echo "  -             : Skip the corresponding parameter"
    echo
    echo "Examples:"
    echo "  $0                      # Use defaults (04:00, Asia/Tokyo)"
    echo "  $0 \"03:00\"             # Set time only"
    echo "  $0 \"03:00\" \"UTC\"       # Set both time and timezone"
    echo "  $0 - \"Europe/London\"    # Set timezone only"
}

# Error handling function
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Validate time format
validate_time() {
    local time=$1
    if ! [[ $time =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        error_exit "Invalid time format. Please use 24-hour format (HH:MM)"
    fi
}

# Validate timezone
validate_timezone() {
    local tz=$1
    if [ ! -f "/usr/share/zoneinfo/$tz" ]; then
        error_exit "Invalid timezone '$tz'. Use 'timedatectl list-timezones' to see available options"
    fi
}

# Check if container exists and is running
check_container() {
    if ! docker ps -q -f name="^/${CONTAINER_NAME}$"; then
        error_exit "Nextcloud container '${CONTAINER_NAME}' is not running"
    fi
}

# Execute docker command safely
docker_exec() {
    if ! docker exec "$@"; then
        error_exit "ERROR: Docker command failed: docker exec $*"
    fi
}

# Set system and container timezone
set_timezone() {
    local tz=$1
    echo "Setting timezone to '$tz'..."
    
    # Set system timezone
    if ! timedatectl set-timezone "$tz"; then
        error_exit "ERROR: Failed to set system timezone"
    fi
    
    # Update container timezone
    docker_exec "$CONTAINER_NAME" bash -c "ln -snf /usr/share/zoneinfo/$tz /etc/localtime && echo $tz > /etc/timezone"
    
    # Update Nextcloud timezone
    docker_exec -u www-data "$CONTAINER_NAME" php occ config:system:set default_timezone --value="$tz"
    
    echo "INFO: Timezone configured successfully"
}

# Set maintenance window start time
set_maintenance_time() {
    local time=$1
    echo "Setting maintenance window start time to '$time'..."
    
    # Convert to UTC
    local localtime
    localtime=$(date -d "$time" +%s) || error_exit "Failed to parse local time"
    
    local utc_hour
    utc_hour=$(date -u -d "@$localtime" "+%-H") || error_exit "Failed to convert to UTC"
    
    echo "Converting $time $(timedatectl show --property=Timezone --value) to ${utc_hour}:00 UTC"
    
    # Update Nextcloud configuration
    docker_exec -u www-data "$CONTAINER_NAME" php occ config:system:set maintenance_window_start --type=integer --value="$utc_hour"
    
    echo "INFO: Maintenance window time configured successfully"
}

# Show current configuration
show_current_config() {
    echo "Current Configuration:"
    echo "---------------------"
    echo "System timezone              : $TIME $(timedatectl show --property=Timezone --value)"
    echo "Nextcloud Maintenance window : $(docker exec -u www-data "$CONTAINER_NAME" php occ config:system:get maintenance_window_start):00 UTC"
    echo
}

main() {
    # Show help if requested
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        print_usage
        exit 0
    fi
    
    # Check container status
    check_container
    
    # Show current configuration
    show_current_config
    
    # Handle timezone if provided
    if [ "$TIMEZONE" != "Asia/Tokyo" ] || [ "${2:-}" = "-" ]; then
        validate_timezone "$TIMEZONE"
        set_timezone "$TIMEZONE"
    fi
    
    # Handle maintenance time if provided and not skipped
    if [ "${1:-}" != "-" ]; then
        validate_time "$TIME"
        set_maintenance_time "$TIME"
    fi
    
    echo
    echo "INFO: Configuration completed successfully!"
    show_current_config
}

main "$@"