#!/bin/bash

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): [INFO] $1"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): [ERROR] $1" >&2
}

log "Sourcing profile"
[[ -f /home/lima.linux/.act_runner/profile ]] && source /home/lima.linux/.act_runner/profile

log "Starting act_runner daemon"
/usr/local/bin/act_runner daemon --config /home/lima.linux/.act_runner/config.yaml 2>&1