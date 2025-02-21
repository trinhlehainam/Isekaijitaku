#!/bin/bash

# Source environment variables
if [ -f /etc/act_runner/colima.cfg ]; then
    source /etc/act_runner/colima.cfg
fi

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): [INFO] $1"
}

# Function to log errors
error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): [ERROR] $1" >&2
}

# Function to check if network is available
check_network() {
    for _ in $(seq 1 30); do
        if ping -c 1 1.1.1.1 >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    return 1
}

# Function to check if Colima is running
is_colima_running() {
    local status
    status=$(colima status 2>&1)
    case "$status" in
        *"colima is running"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to start Colima with configuration
start_colima() {
    local -a cmd=(colima start)
    cmd+=("--cpu" "${COLIMA_CPU:-4}")
    cmd+=("--memory" "${COLIMA_MEMORY:-8}")
    cmd+=("--disk" "${COLIMA_DISK:-100}")
    cmd+=("--vm-type" "${COLIMA_VM_TYPE:-vz}")
    
    if [ "${COLIMA_VM_TYPE:-vz}" = "vz" ] && [ -n "${COLIMA_ROSETTA}" ]; then
        cmd+=("--vz-rosetta")
    fi

    if [ -n "${COLIMA_MOUNT_TYPE}" ]; then
        cmd+=("--mount-type" "${COLIMA_MOUNT_TYPE}")
    fi
    if [ -n "${COLIMA_RUNTIME}" ]; then
        cmd+=("--runtime" "${COLIMA_RUNTIME}")
    fi

    log "Executing: ${cmd[*]}"
    "${cmd[@]}"
    return $?
}

# Function to attempt starting Colima with retries
start_colima_with_retry() {
    local max_attempts=3
    local attempt=1
    local wait_time=10

    while [ $attempt -le $max_attempts ]; do
        log "Attempting to start Colima (attempt $attempt/$max_attempts)"
        
        if start_colima; then
            # Wait for Colima to fully initialize
            local init_attempts=12
            local init_attempt=1
            while [ $init_attempt -le $init_attempts ]; do
                if is_colima_running; then
                    log "Colima started successfully"
                    # Clean up temporary files if using virtiofs to allow other users to start their instances
                    if [ "${COLIMA_MOUNT_TYPE:-}" = "virtiofs" ]; then
                        log "Cleaning up temporary files for virtiofs"
                        rm -rf /tmp/colima
                        rm -f /tmp/colima.yaml
                    fi
                    return 0
                fi
                log "Waiting for Colima to initialize (attempt $init_attempt/$init_attempts)..."
                sleep 5
                init_attempt=$((init_attempt + 1))
            done
        fi

        if [ $attempt -lt $max_attempts ]; then
            log "Start attempt failed. Waiting $wait_time seconds before retry..."
            sleep $wait_time
            wait_time=$((wait_time * 2))  # Exponential backoff
        fi
        attempt=$((attempt + 1))
    done

    error "Failed to start Colima after $max_attempts attempts"
    return 1
}

# Stop any running instance
if is_colima_running; then
    log "Stopping running Colima instance"
    colima stop
    
    # Wait for Colima to stop with retry
    max_attempts=6
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if ! is_colima_running; then
            log "Colima stopped successfully"
            break
        fi
        log "Waiting for Colima to stop (attempt $attempt/$max_attempts)..."
        sleep 5
        attempt=$((attempt + 1))
    done

    if [ $attempt -gt $max_attempts ]; then
        error "Failed to stop Colima after $max_attempts attempts"
        exit 1
    fi
fi

# Wait for network
if ! check_network; then
    error "Network check failed"
    exit 1
fi

# Start Colima with retry
if ! start_colima_with_retry; then
    exit 1
fi

log "Colima started successfully"