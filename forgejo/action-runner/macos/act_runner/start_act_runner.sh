#!/bin/bash

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): [INFO] $1"
}

# Function to log errors
error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): [ERROR] $1" >&2
}

# Profile config environment variables
log "Sourcing profile"
[[ -f /etc/act_runner/profile ]] && source /etc/act_runner/profile

# Start act_runner daemon
log "Starting act_runner daemon"
/usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml 2>&1