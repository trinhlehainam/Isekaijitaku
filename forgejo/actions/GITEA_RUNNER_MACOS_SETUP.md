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

**Important**: Before downloading, check your CPU architecture and select the appropriate binary:
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

# Set ownership and permissions
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
DOCKER_HOST="unix:///Users/COLIMA_USER/.colima/default/docker.sock"
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
# Switch to _act_runner user
sudo -u _act_runner bash

# Set up Colima configuration directory
mkdir -p /var/lib/act_runner/.colima

# Create Colima configuration
cat > /var/lib/act_runner/.colima/default/colima.yaml << EOF
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
sudo -u _act_runner colima start
```

3. Verify Docker access:
```bash
sudo -u _act_runner docker ps
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
sudo tee /usr/local/scripts/start-act-runner-colima.sh << EOF
#!/bin/bash

# Source environment variables
if [ -f /etc/act_runner/colima.env ]; then
    source /etc/act_runner/colima.env
fi

# Function to log messages
log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S'): [INFO] \$1" >> /var/lib/act_runner/colima.log
}

# Function to log errors
error() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S'): [ERROR] \$1" >> /var/lib/act_runner/colima.error
    echo "\$(date '+%Y-%m-%d %H:%M:%S'): [ERROR] \$1" >> /var/lib/act_runner/colima.log
}

# Function to check if network is available
check_network() {
    for i in \$(seq 1 30); do
        if ping -c 1 1.1.1.1 >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    return 1
}

# Wait for network
if ! check_network; then
    error "Network check failed"
    exit 1
fi

# Build Colima command with resource configurations
log "Starting Colima..."
cmd="colima start"
cmd="\$cmd --cpu \${COLIMA_CPU:-4}"
cmd="\$cmd --memory \${COLIMA_MEMORY:-8}"
cmd="\$cmd --disk \${COLIMA_DISK:-100}"
cmd="\$cmd --vm-type \${COLIMA_VM_TYPE:-vz}"

# Add optional configurations if specified
if [ -n "\$COLIMA_MOUNT_TYPE" ]; then
    cmd="\$cmd --mount-type \$COLIMA_MOUNT_TYPE"
fi

# Start Colima
log "Executing: \$cmd"
eval "\$cmd"

# Check if Colima started successfully
if ! colima status | grep -q "Running"; then
    error "Failed to start Colima"
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
    <string>/var/lib/act_runner/colima.log</string>
    <key>StandardErrorPath</key>
    <string>/var/lib/act_runner/colima.error</string>
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
sudo -u _act_runner colima status

# Verify Docker access
sudo -u _act_runner docker info
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

# Create pyenv profile script
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

# Verify installation
arch -arm64 sudo -u _act_runner HOME=/var/lib/act_runner bash -c 'source /etc/act_runner/pyenv.sh && python --version && pyenv version'
```

### 6. Create and Configure LaunchDaemon

1. Create the start script for act_runner:
```bash
sudo tee /usr/local/bin/start_act_runner.sh << 'EOF'
#!/bin/bash

# Source nvm and pyenv
source /etc/act_runner/nvm.sh
source /etc/act_runner/pyenv.sh

# Start act_runner daemon
exec /usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml
EOF

sudo chown root:wheel /usr/local/bin/start_act_runner.sh
sudo chmod 755 /usr/local/bin/start_act_runner.sh
```

2. Create the LaunchDaemon configuration:
```bash
sudo tee /Library/LaunchDaemons/com.gitea.act_runner.plist << EOF
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
    <string>/var/lib/act_runner/act_runner.log</string>
    <key>StandardErrorPath</key>
    <string>/var/lib/act_runner/act_runner.error</string>
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

### 8. Test the Runner Setup

Create a test workflow in your repository to verify the runner setup:

```yaml
name: Test MacOS Runner Setup

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  test-native:
    name: Test Native MacOS Commands
    runs-on: macos-sonoma-m1  # Use your runner label
    steps:
      - uses: actions/checkout@v4
      
      - name: Test Basic Commands
        run: |
          uname -a
          sw_vers
          
      - name: Test Environment
        run: |
          echo "HOME: $HOME"
          echo "PATH: $PATH"
          env
          
      - name: Test File Operations
        run: |
          touch test.txt
          echo "Hello from MacOS Runner" > test.txt
          cat test.txt
          ls -la
          
      - name: Test Network
        run: |
          curl --version
          ping -c 4 8.8.8.8

  test-docker:
    name: Test Docker Functionality
    runs-on: macos-sonoma-m1  # Use your runner label
    steps:
      - uses: actions/checkout@v4
      
      - name: Test Docker Installation
        run: |
          docker --version
          docker info
          
      - name: Test Docker Pull
        run: |
          docker pull hello-world
          docker images
          
      - name: Test Docker Run
        run: |
          docker run hello-world
          docker ps -a

  test-complex:
    name: Test Complex Workflow
    runs-on: macos-sonoma-m1  # Use your runner label
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        run: |
          python -V
          python -m pip install --upgrade pip
          
      - name: Create Python Script
        run: |
          cat > test.py << 'EOF'
          import os
          import sys
          import platform
          
          print("Python Version:", sys.version)
          print("Platform Info:", platform.platform())
          print("Current Directory:", os.getcwd())
          
          # Create and read a file
          with open('output.txt', 'w') as f:
              f.write("Test successful!")
          
          with open('output.txt', 'r') as f:
              print("File contents:", f.read())
          EOF
          
      - name: Run Python Script
        run: python test.py
        
      - name: Test File Persistence
        run: |
          ls -la
          cat output.txt
```

{{ ... }}

## Troubleshooting

1. Check daemon status:
```bash
sudo launchctl list | grep act_runner
```

2. View logs:
```bash
tail -f /var/lib/act_runner/act_runner.log
tail -f /var/lib/act_runner/act_runner.err
```

3. Restart the daemon:
```bash
sudo launchctl unload /Library/LaunchDaemons/com.gitea.act_runner.plist
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
```

## References
- [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/act-runner)
- [Forgejo Actions Documentation](https://forgejo.org/docs/latest/admin/actions/)
- [Forgejo Runner Installation Guide](https://forgejo.org/docs/latest/admin/runner-installation/)
- [MacOS Daemons and Agents](https://wiki.lazarus.freepascal.org/macOS_daemons_and_agents)
- [Creating MacOS Daemon Users](https://stackoverflow.com/questions/32810960/create-user-for-running-a-daemon-on-macos-x)
- [Running uname -m gives x86_64 on M1 Mac Mini](https://apple.stackexchange.com/questions/420452/running-uname-m-gives-x86-64-on-m1-mac-mini)
- [M1 Mac — How to switch the Terminal between x86_64 and arm64](https://vineethbharadwaj.medium.com/m1-mac-switching-terminal-between-x86-64-and-arm64-e45f324184d9)