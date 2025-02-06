#!/bin/bash

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): [INFO] $1"
}

# Function to log errors
error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): [ERROR] $1" >&2
}

# Source nvm and pyenv
log "Sourcing nvm and pyenv"
source /etc/act_runner/nvm.sh
source /etc/act_runner/pyenv.sh

# Start act_runner daemon
log "Starting act_runner daemon"
/usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml 2>&1