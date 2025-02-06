# Setting Up Gitea Action Runner on MacOS for Forgejo Instance

This guide explains how to set up Gitea Action Runner on MacOS to work with a Forgejo instance, since Forgejo Actions currently doesn't support MacOS and Windows hosts natively.

## Prerequisites

- MacOS operating system
- Administrative privileges (sudo access)
- A running Forgejo instance
- Access to Forgejo dashboard with admin privileges

## MacOS System Daemon Overview

On MacOS, system daemons are background processes that run in the system context, managed by `launchd` - the system-wide daemon manager started by the kernel during boot. Unlike user agents that run in user context, daemons operate system-wide with only one instance for all clients.

### Understanding MacOS Daemon Management

- `launchd` is the system-wide daemon manager that handles process management
- Daemon processes are typically prefixed with underscore (e.g., `_act_runner`) to denote they are system daemons
- Daemon users should use UIDs below 1024 (we use 385 for act_runner)
- Daemons are configured via property list (plist) files in `/Library/LaunchDaemons/`

### Finding Available System IDs

Before creating a new daemon user, you can find available system IDs using:
```bash
# List last used group IDs
dscacheutil -q group | grep gid | awk '{print $2}' | sort -n | tail -n 15

# Or just get the highest used GID
dscacheutil -q group | grep gid | awk '{print $2}' | sort -n | tail -n 1
```

## Installation Steps

### 1. Download and Install Runner

> **Important**: Before downloading, check your CPU architecture and select the appropriate binary:
```bash
# Check CPU and architecture
sysctl -n machdep.cpu.brand_string   # Check if Apple M-series or Intel
arch                                 # Check current architecture

# Note: On M-series Macs, even if terminal shows x86_64 (Rosetta),
# you can still download and run arm64 binaries for better performance.

# Check available versions at:
# https://dl.gitea.com/act_runner/

# Download appropriate version based on architecture:
# - For M-series (ARM): act_runner-VERSION-darwin-arm64 (recommended for M-series, even under Rosetta)
# - For Intel: act_runner-VERSION-darwin-amd64 (only for Intel Macs)
```

```bash
# Set architecture for download
if echo "$(sysctl -n machdep.cpu.brand_string)" | grep -q "Apple M"; then
    # For M-series Macs, use arm64 even if running under Rosetta
    ARCH="arm64"
else
    # For Intel Macs
    ARCH="amd64"
fi

# Set version
VERSION="0.2.11"  # Check https://dl.gitea.com/act_runner/ for latest version

# Download specific version of darwin binary from Gitea releases
curl -L -o act_runner "https://dl.gitea.com/act_runner/${VERSION}/act_runner-${VERSION}-darwin-${ARCH}"

# Make binary executable
chmod +x act_runner

# Move to system bin directory
sudo mv act_runner /usr/local/bin/
```

### 2. Create System Daemon User

First, check if the group ID and user ID are available:
```bash
# Check if group ID 385 is already in use
dscl . -list /Groups PrimaryGroupID | grep 385
# Check if user ID 385 is already in use
dscl . -list /Users UniqueID | grep 385

# If you need to find an available ID, list the last used IDs:
echo "Last used Group IDs:"
dscacheutil -q group | grep gid | awk '{print $2}' | sort -n | tail -n 5
echo "Last used User IDs:"
dscacheutil -q user | grep uid | awk '{print $2}' | sort -n | tail -n 5
```

If the IDs are available, create the group and user:
```bash
# Create _act_runner group first
sudo dscl . -create /Groups/_act_runner
sudo dscl . -create /Groups/_act_runner PrimaryGroupID 385

# Create _act_runner user with home directory
sudo dscl . -create /Users/_act_runner
sudo dscl . -create /Users/_act_runner UserShell /usr/bin/false
sudo dscl . -create /Users/_act_runner RealName "Gitea Action Runner"
sudo dscl . -create /Users/_act_runner UniqueID 385
sudo dscl . -create /Users/_act_runner PrimaryGroupID 385
sudo dscl . -create /Users/_act_runner NFSHomeDirectory /var/lib/act_runner
```

2. Set up configuration directory:
```bash
# Create config directory
sudo mkdir -p /etc/act_runner

# Set ownership
sudo chown -R _act_runner:_act_runner /etc/act_runner
```

3. Verify setup:
```bash
# Check user information
sudo dscl . -read /Users/_act_runner

# Check directory permissions
ls -la /var/lib/act_runner /etc/act_runner
```

Note: The home directory `/var/lib/act_runner` is automatically created by the system when setting up the user. This path must match the working directory specified in the launchd daemon configuration file.

### 2.1 Configure Docker Access for _act_runner (Optional)

If you plan to use Docker with the runner, you have two options:

#### Option 1: Share Existing Colima Instance (Less Secure)

If Colima is already running by another user and you want to share it:

1. Find the existing Colima Docker socket:
```bash
# Get socket location from Colima status
colima status

# Default location is in user's home directory
# For example, if run by 'admin' user:
ls -l /Users/admin/.colima/default/docker.sock
```

2. Add _act_runner to docker group:
```bash
# Create docker group if it doesn't exist
sudo dscl . -create /Groups/docker
sudo dscl . -create /Groups/docker PrimaryGroupID 1001  # Use a free GID
sudo dscl . -create /Groups/docker GroupMembership $(whoami)

# Add _act_runner to docker group
sudo dscl . -append /Groups/docker GroupMembership _act_runner

# Set socket group ownership
sudo chown COLIMA_USER:docker /Users/COLIMA_USER/.colima/default/docker.sock
sudo chmod g+rw /Users/COLIMA_USER/.colima/default/docker.sock
```

3. Configure Docker host for _act_runner:
```bash
# Create environment file directory
sudo mkdir -p /etc/act_runner
sudo chown _act_runner:_act_runner /etc/act_runner

# Create environment file
sudo -u _act_runner tee /etc/act_runner/environment << EOF
EOF
# Replace COLIMA_USER with the username running Colima
```

4. Test Docker access:
```bash
sudo -u _act_runner bash -c 'source /etc/act_runner/environment && docker ps'
```

Note: Replace `COLIMA_USER` with the actual username that runs Colima. The socket path can be found using `colima status`.

#### Option 2: Run Separate Colima Instance (Recommended)

This is the recommended approach as it provides better isolation and security. Here's why:

1. Security Benefits:
   - Each runner has its own isolated Docker environment
   - No shared socket access between users
   - Runner jobs can't interfere with other Docker workloads
   - No need to modify system-wide permissions or group memberships

2. Resource Management:
   - Dedicated CPU and memory allocation for runner jobs
   - No resource contention with other Docker workloads
   - Better performance predictability for CI/CD jobs

3. Maintenance Benefits:
   - Independent lifecycle management
   - Can update or restart Docker without affecting other users
   - Easier to debug issues specific to the runner
   - Clean separation of concerns

Setup steps:

1. Configure Colima for _act_runner:
```bash
# Set up Colima configuration directory
sudo -u _act_runner mkdir -p /var/lib/act_runner/.colima

# Create Colima configuration
sudo -u _act_runner cat > /var/lib/act_runner/.colima/default/colima.yaml << EOF
cpu: 4
memory: 8
disk: 100
arch: aarch64  # Use 'x86_64' for Intel Macs
vm:
  type: "vz"   # Use 'qemu' for Intel Macs
EOF

# Exit _act_runner shell
exit
```

2. Start Colima as _act_runner:
```bash
sudo -u _act_runner HOME=/var/lib/act_runner colima start
```

3. Verify Docker access:
```bash
sudo -u _act_runner DOCKER_HOST="unix:///var/lib/act_runner/.colima/default/docker.sock" docker ps
```

Note: 
- If you're using an Intel Mac, replace `arch: aarch64` with `x86_64` and `type: "vz"` with `type: "qemu"` in the configuration.
- Option 2 is recommended as it provides complete isolation and avoids potential security issues with shared Docker sockets.
- Colima automatically manages the Docker socket and environment variables, so no additional configuration is needed.
- The home directory is set to `/var/lib/act_runner` for proper file storage and permissions.

### 3. Configure Colima for act_runner

Configure Colima for the _act_runner user (reference: [[202501061959 Set up MacOS as private server with Tailscale and Docker]]):

1. Add _act_runner user to _colima group:
```bash
# Add _act_runner to _colima group
sudo dscl . -append /Groups/_colima GroupMembership _act_runner

# Verify group membership
dscl . -read /Groups/_colima GroupMembership
```

2. Create Colima configuration for _act_runner:
```bash
# Create configuration directory
sudo mkdir -p /var/lib/act_runner/.colima
sudo mkdir -p /var/lib/act_runner/.lima
sudo chown -R _act_runner:_act_runner /var/lib/act_runner/.colima
sudo chown -R _act_runner:_act_runner /var/lib/act_runner/.lima

# Create Colima environment file
sudo tee /etc/act_runner/colima.env << EOF
# Colima resource configuration
COLIMA_CPU=4
COLIMA_MEMORY=8
COLIMA_DISK=100
COLIMA_VM_TYPE=vz

# Optional configurations
#
# For better performance on macOS 13+
# COLIMA_MOUNT_TYPE=virtiofs  
#
# Specify container runtime (docker/containerd)
# COLIMA_RUNTIME=docker   
EOF

sudo chown root:wheel /etc/act_runner/colima.env
sudo chmod 644 /etc/act_runner/colima.env

# Create start script
sudo tee /usr/local/scripts/start-act-runner-colima.sh << 'EOF'
#!/bin/bash

# Source environment variables
if [ -f /etc/act_runner/colima.env ]; then
    source /etc/act_runner/colima.env
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
    for i in $(seq 1 30); do
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
EOF

sudo chmod 755 /usr/local/scripts/start-act-runner-colima.sh
```

3. Create LaunchDaemon for act_runner's Colima:
```bash
sudo tee /Library/LaunchDaemons/com.gitea.act_runner.colima.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.gitea.act_runner.colima</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/scripts/start-act-runner-colima.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>UserName</key>
    <string>_act_runner</string>
    <key>GroupName</key>
    <string>_act_runner</string>
    <key>StandardOutPath</key>
    <string>/var/log/act_runner/colima.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/act_runner/colima.error</string>
    <key>WorkingDirectory</key>
    <string>/var/lib/act_runner</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>/var/lib/act_runner</string>
    </dict>
</dict>
</plist>
EOF

# Set proper permissions
sudo chown root:wheel /Library/LaunchDaemons/com.gitea.act_runner.colima.plist
sudo chmod 644 /Library/LaunchDaemons/com.gitea.act_runner.colima.plist

# Load the daemon
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.colima.plist

# Verify Colima is running
sudo -u _act_runner HOME=/var/lib/act_runner colima status

# Verify Docker access
sudo -u _act_runner DOCKER_HOST="unix:///var/lib/act_runner/.colima/default/docker.sock" docker info

# Restart the daemon
sudo launchctl unload /Library/LaunchDaemons/com.gitea.act_runner.colima.plist
sudo -u _act_runner HOME=/var/lib/act_runner colima stop
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.colima.plist
```

### 4. Install Node.js for Runner

The GitHub Actions runner requires Node.js for many common actions. Install it using nvm (Node Version Manager). For Node.js version information, check [Node.js Downloads](https://nodejs.org/en/download).

1. Install nvm and Node.js:
```bash
# Create .nvm directory
sudo mkdir -p /var/lib/act_runner/.nvm
sudo chown -R _act_runner:_act_runner /var/lib/act_runner/.nvm

# Install nvm and Node.js LTS
sudo -u _act_runner HOME=/var/lib/act_runner bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"

# Create nvm profile script
sudo tee /etc/act_runner/nvm.sh << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
EOF

sudo chown root:wheel /etc/act_runner/nvm.sh
sudo chmod 644 /etc/act_runner/nvm.sh

# Install Node.js and enable pnpm
sudo -u _act_runner HOME=/var/lib/act_runner bash -c 'source /etc/act_runner/nvm.sh && nvm install 22 && corepack enable pnpm'

# Verify installations
sudo -u _act_runner HOME=/var/lib/act_runner bash -c 'source /etc/act_runner/nvm.sh && node -v && nvm current && pnpm -v'
```

### 5. Install Python for Runner

The GitHub Actions runner often requires Python for various tasks. Install it using pyenv (Python Version Manager). For detailed configuration options and advanced settings that can be applied later, check [pyenv on GitHub](https://github.com/pyenv/pyenv).

1. Install pyenv and build dependencies using Homebrew:
```bash
# Install pyenv
brew update && brew install pyenv

# Install build dependencies
brew install xz openssl readline sqlite3 zlib tcl-tk
```

2. Set up pyenv for _act_runner:
```bash
# Create pyenv directory
sudo mkdir -p /var/lib/act_runner/.pyenv
sudo chown -R _act_runner:_act_runner /var/lib/act_runner/.pyenv

# Create pyenv profile script with build environment variables
sudo tee /etc/act_runner/pyenv.sh << 'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
EOF

sudo chown root:wheel /etc/act_runner/pyenv.sh
sudo chmod 644 /etc/act_runner/pyenv.sh

# List available Python versions
arch -arm64 sudo -u _act_runner HOME=/var/lib/act_runner bash -c 'source /etc/act_runner/pyenv.sh && pyenv install --list'

# Install Python 3.12 (using arm64 architecture)
arch -arm64 sudo -u _act_runner HOME=/var/lib/act_runner bash -c 'source /etc/act_runner/pyenv.sh && pyenv install 3.12'

# Set global Python version
arch -arm64 sudo -u _act_runner HOME=/var/lib/act_runner bash -c 'source /etc/act_runner/pyenv.sh && pyenv global 3.12'

# Verify installation and lzma support
arch -arm64 sudo -u _act_runner HOME=/var/lib/act_runner bash -c 'source /etc/act_runner/pyenv.sh && python --version && pyenv version'
```

### 6. Create and Configure LaunchDaemon

> **Note about log redirection**: The act_runner daemon writes most of its operational logs to stderr instead of stdout. Without `2>&1` redirection, these logs would only appear in the error log file, making it harder to track the chronological sequence of events. By using `2>&1`, we redirect stderr to stdout, ensuring all logs are written to the same file in the order they occur. This is particularly important for debugging issues and monitoring the runner's behavior, as it keeps all related log entries together in a single, properly ordered log file.

1. Create log directory:
```bash
# Create log directory
sudo mkdir -p /var/log/act_runner
sudo chown _act_runner:_act_runner /var/log/act_runner
sudo chmod 755 /var/log/act_runner
```

2. Create the start script for act_runner:
```bash
sudo tee /usr/local/bin/start_act_runner.sh << 'EOF'
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
EOF

sudo chown root:wheel /usr/local/bin/start_act_runner.sh
sudo chmod 755 /usr/local/bin/start_act_runner.sh
```

3. Create the LaunchDaemon configuration:
```bash
sudo tee /Library/LaunchDaemons/com.gitea.act_runner.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.gitea.act_runner</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/start_act_runner.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>_act_runner</string>
    <key>GroupName</key>
    <string>_act_runner</string>
    <key>StandardOutPath</key>
    <string>/var/log/act_runner/act_runner.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/act_runner/act_runner.error</string>
    <key>WorkingDirectory</key>
    <string>/var/lib/act_runner</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>/var/lib/act_runner</string>
        <key>NVM_DIR</key>
        <string>/var/lib/act_runner/.nvm</string>
        <key>PYENV_ROOT</key>
        <string>/var/lib/act_runner/.pyenv</string>
    </dict>
</dict>
</plist>
EOF

sudo chown root:wheel /Library/LaunchDaemons/com.gitea.act_runner.plist
sudo chmod 644 /Library/LaunchDaemons/com.gitea.act_runner.plist
```

### 7. Start the Service

1. Load the LaunchDaemon:
```bash
# Unload the daemon if it's already loaded
sudo launchctl unload /Library/LaunchDaemons/com.gitea.act_runner.plist

# Load the daemon
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
```

2. Monitor logs
```bash
tail -f /var/log/act_runner/act_runner.log
tail -f /var/log/act_runner/act_runner.error
```

## Register Runner with Forgejo Instance

The runner must be registered with your Forgejo instance before it can accept jobs. For CI/CD automation, we'll use the non-interactive registration method.

### 3.2. Configure Runner

> **Important**: First, check your CPU type:
```bash
# Check if you have M-series or Intel CPU
sysctl -n machdep.cpu.brand_string
```
> For M-series Macs only, you can switch between architectures:
```bash
# Check current architecture
arch

# Switch to ARM (native, recommended for better performance)
arch -arm64 /bin/bash --login

# Switch to x86_64 (Rosetta, for compatibility)
arch -x86_64 /bin/bash --login
```
> Note: The runner will run in the same architecture as the terminal used to install it.
> For Intel Macs, you can only use x86_64 architecture.

1. Generate default configuration:
```bash
# Generate default config
act_runner generate-config > /tmp/config.yaml

# Move to final location with correct permissions
sudo mv /tmp/config.yaml /etc/act_runner/config.yaml
sudo chown _act_runner:_act_runner /etc/act_runner/config.yaml

# Set runner file path
sudo yq -i '.runner.file = "/var/lib/act_runner/.runner"' /etc/act_runner/config.yaml
```

Get macOS version name and set up name mapping:
```bash
MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)

# Create a function to map macOS version to name
get_macos_name() {
    case "$1" in
        14) echo "sonoma" ;;
        13) echo "ventura" ;;
        12) echo "monterey" ;;
        11) echo "bigsur" ;;
        10) echo "catalina" ;;
        *) echo "unknown" ;;
    esac
}

# Get the macOS name
MACOS_NAME=$(get_macos_name "$MACOS_VERSION")

# Get CPU type and current architecture
CHIP_INFO=$(sysctl -n machdep.cpu.brand_string)
CURRENT_ARCH=$(arch)

# Install yq if not already installed
brew install yq

# Set label based on CPU type
if echo "${CHIP_INFO}" | grep -q "Apple M"; then
    RUNNER_LABEL="macos-${MACOS_NAME}-m1:host"
else
    RUNNER_LABEL="macos-${MACOS_NAME}-x86_64:host"
fi

# Update only the labels in config file
sudo yq -i '.runner.labels = ["'"${RUNNER_LABEL}"'"]' /etc/act_runner/config.yaml
```

Note: The runner will automatically use subdirectories in `/var/lib/act_runner` for logs and cache.
Labels are set based on the Mac's processor:
- M-series Mac: `macos-sonoma-m1:host` (can run both arm64 and x86_64)
- Intel Mac: `macos-sonoma-x86_64:host`

### 3.3. Register Runner (Non-Interactive)

1. Set environment variables:
```bash
FORGEJO_INSTANCE_URL="https://forgejo.example.com"
RUNNER_TOKEN="your_runner_token"
```

2. Register the runner:
```bash
sudo -u _act_runner act_runner register \
  --instance ${FORGEJO_INSTANCE_URL} \
  --token ${RUNNER_TOKEN} \
  --name $(cat /etc/act_runner/config.yaml | yq e '.runner.name' -) \
  --no-interactive
```

### 3.4. Configure Runner Permissions

> **Important**: macOS has specific security policies that affect sudo behavior:
> 1. macOS maintains its own security database separate from `/etc/sudoers`
> 2. The security system requires authentication even when NOPASSWD is set
> 3. Sudo access should be avoided in runner actions to prevent hanging

There are two approaches to handle runner permissions:

#### Option A: Direct Permissions (Recommended)

This approach avoids sudo usage by setting up proper permissions:

```bash
# Set up workspace with proper permissions
echo "Setting up workspace permissions..."
sudo mkdir -p /var/lib/act_runner/workspace
sudo chown -R _act_runner:staff /var/lib/act_runner
sudo chmod -R 755 /var/lib/act_runner
```

#### Option B: Limited Sudo Access (Use with Caution)

If certain commands absolutely require sudo:

```bash
# Create a secure sudoers file for act_runner
echo "Configuring minimal sudo access..."

# First, create a temporary file with strict permissions
sudo touch /tmp/act_runner_sudoers
sudo chmod 440 /tmp/act_runner_sudoers

sudo tee /tmp/act_runner_sudoers << 'EOF'
# Minimal sudo access for _act_runner
# Essential workspace operations
_act_runner ALL=(ALL) NOPASSWD: /bin/mkdir -p /var/lib/act_runner/workspace/*
_act_runner ALL=(ALL) NOPASSWD: /bin/chmod -R 755 /var/lib/act_runner/workspace/*
_act_runner ALL=(ALL) NOPASSWD: /usr/sbin/chown -R _act_runner\:staff /var/lib/act_runner/workspace/*
EOF

# Verify syntax before installing
sudo visudo -cf /tmp/act_runner_sudoers && {
    sudo mv /tmp/act_runner_sudoers /etc/sudoers.d/act_runner
    echo "✓ Sudo configuration installed successfully"
} || {
    echo "❌ Sudo configuration syntax check failed"
    sudo rm /tmp/act_runner_sudoers
    exit 1
}
```

### 3.5. Verify Runner Security Settings

Before proceeding, verify the `_act_runner` user's security configuration. macOS has specific security policies that we need to verify:

1. Authentication database is separate from Unix-style `/etc/passwd`
2. Password policies are managed by `pwpolicy`
3. User attributes are managed through Directory Services

> **References**:
> - [Understanding macOS sudo behavior and security](https://superuser.com/a/510015)
> - [macOS user authentication and password policies](https://superuser.com/a/1394494)

```bash
# 1. Check Authentication Mechanisms
echo "Verifying authentication configuration..."
{
    # Check authentication authority (should not exist)
    sudo dscl . -read /Users/_act_runner AuthenticationAuthority 2>&1 | grep "No such key" && \
    echo "✓ No authentication authority (correct for service account)"

    # Check password hash (should not exist)
    sudo dscl . -read /Users/_act_runner Password 2>&1 | grep "No such key" && \
    echo "✓ No password mechanism (correct for service account)"

    # Verify password policy
    sudo pwpolicy -u _act_runner -getpolicy 2>&1 | grep "Error" && \
    echo "✓ No password policy (correct for service account)" || \
    echo "❌ Unexpected password policy found"
} || echo "❌ Authentication check failed"

# 2. Check Service Account Configuration
echo "Verifying service account settings..."
{
    # Check shell configuration
    sudo dscl . -read /Users/_act_runner UserShell | grep -E "(/usr/bin/false|/sbin/nologin)" && \
    echo "✓ Non-interactive shell configured"

    # Check home directory
    sudo dscl . -read /Users/_act_runner NFSHomeDirectory | grep "/var/lib/act_runner" && \
    echo "✓ Home directory correctly set"

    # Check user ID (should be < 500 for service account)
    sudo dscl . -read /Users/_act_runner UniqueID | awk '{if ($2 < 500) print "✓ Service account UID (" $2 ")"}' || \
    echo "❌ Invalid UID for service account"

    # Verify account type
    sudo dscl . -read /Users/_act_runner RecordType | grep "Users" && \
    echo "✓ User record type verified"
} || echo "❌ Service account configuration check failed"

# 3. Check Security Context
echo "Verifying security context..."
{
    # Check primary group
    sudo dscl . -read /Users/_act_runner PrimaryGroupID | grep -E "^PrimaryGroupID: [1-9][0-9]*$" && \
    echo "✓ Primary group configured"

    # Check admin group membership (should fail)
    sudo dseditgroup -o checkmember -m _act_runner admin 2>&1 | grep "NOT" && \
    echo "✓ Not in admin group"

    # Check wheel group membership (should fail)
    sudo dseditgroup -o checkmember -m _act_runner wheel 2>&1 | grep "NOT" && \
    echo "✓ Not in wheel group"
} || echo "❌ Security context check failed"

# 4. Check Workspace Permissions
echo "Verifying workspace permissions..."
{
    # Check workspace directory
    ls -ld /var/lib/act_runner/workspace | grep "^drwxr-xr-x.*_act_runner.*staff" && \
    echo "✓ Workspace permissions correct"

    # Test workspace access
    sudo -u _act_runner bash << 'EOF'
    cd /var/lib/act_runner/workspace && \
    touch test.txt && \
    rm test.txt && \
    echo "✓ Workspace access verified"
EOF
} || echo "❌ Workspace permission check failed"

# 5. Verify Service Restrictions
echo "Verifying service restrictions..."
{
    # Check login capability
    sudo defaults read /Library/Preferences/com.apple.loginwindow | grep _act_runner && \
    echo "❌ Warning: User appears in login window" || \
    echo "✓ User hidden from login window"

    # Check remote login
    sudo dscl . -read /Users/_act_runner ServiceAccountInfo 2>&1 | grep "No such key" && \
    echo "✓ No remote access configured"
} || echo "❌ Service restriction check failed"
```

Expected Results:
1. **Authentication Status**:
   - No AuthenticationAuthority key
   - No Password key
   - No password policy
   - No login shell

2. **Service Account Properties**:
   - UID < 500
   - Home directory in `/var/lib/act_runner`
   - Primary group configured
   - No admin/wheel group membership

3. **Access Controls**:
   - Workspace permissions: 755
   - Owner: _act_runner:staff
   - No login window access
   - No remote access

> **Security Best Practices**:
> - Regularly verify service account status with `dscl` and `pwpolicy`
> - Monitor system logs for authentication attempts
> - Keep service account isolated from user-accessible areas
> - Maintain restricted workspace permissions
> - Regularly audit group memberships

## Test Runner Setup

Create a test workflow in your repository to verify the runner setup. This workflow will test basic functionality, Docker support, and security restrictions:

- See `actions/test.yaml` for the workflow content

4. Monitor the workflow:
- Go to your repository in Forgejo
- Click on "Actions" tab
- Monitor the progress of each job:
  - **test-native**: Verifies basic system commands and file operations
  - **test-docker**: Validates Docker installation, image building, and cleanup
  - **test-complex**: Tests Python environment and file operations

The workflow tests three key aspects:
1. Native system functionality
2. Docker container operations with proper cleanup
3. Python environment and file operations

If all jobs complete successfully, your MacOS runner is properly configured and ready for use.

## Troubleshooting

1. Check daemon status:
```bash
sudo launchctl list | grep act_runner
```

2. View logs:
```bash
tail -f /var/log/act_runner/act_runner.log
tail -f /var/log/act_runner/act_runner.error
```

3. Restart the daemon:
```bash
sudo launchctl unload /Library/LaunchDaemons/com.gitea.act_runner.plist
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
```

## References
- [[202502062018 Setup Docker on MacOS with Colima]]
- [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/act-runner)
- [Forgejo Actions Documentation](https://forgejo.org/docs/latest/admin/actions/)
- [Forgejo Runner Installation Guide](https://forgejo.org/docs/latest/admin/runner-installation/)
- [MacOS Daemons and Agents](https://wiki.lazarus.freepascal.org/macOS_daemons_and_agents)
- [Creating MacOS Daemon Users](https://stackoverflow.com/questions/32810960/create-user-for-running-a-daemon-on-macos-x)
- [M1 Mac — How to switch the Terminal between x86_64 and arm64](https://vineethbharadwaj.medium.com/m1-mac-switching-terminal-between-x86-64-and-arm64-e45f324184d9)