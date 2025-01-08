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
sudo dscl . -create /Users/_act_runner UserShell /bin/bash
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

### 3. Register Runner with Forgejo Instance

The runner must be registered with your Forgejo instance before it can accept jobs. For CI/CD automation, we'll use the non-interactive registration method.

#### 3.1. Obtain Registration Token

1. Log in to your Forgejo instance with admin privileges
2. Navigate to Site Administration → Actions → Runners
3. Click "Create new runner token"
4. Copy the generated token

#### 3.2. Configure Runner

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

#### 3.3. Register Runner (Non-Interactive)

1. Set environment variables:
```bash
FORGEJO_INSTANCE_URL="https://forgejo.example.com"
RUNNER_TOKEN="your_runner_token"
RUNNER_NAME="macbook-gitea-runner"
```

2. Register the runner:
```bash
sudo -u _act_runner act_runner register \
  --instance ${FORGEJO_INSTANCE_URL} \
  --token ${RUNNER_TOKEN} \
  --name ${RUNNER_NAME} \
  --config /etc/act_runner/config.yaml \
  --no-interactive
```

#### 3.4. Create LaunchDaemon

Create the LaunchDaemon configuration:
```bash
# Create LaunchDaemon plist file
sudo tee /Library/LaunchDaemons/com.gitea.act_runner.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.gitea.act_runner</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/act_runner</string>
        <string>daemon</string>
        <string>--config</string>
        <string>/etc/act_runner/config.yaml</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/var/lib/act_runner</string>
    <key>StandardOutPath</key>
    <string>/var/lib/act_runner/act_runner.log</string>
    <key>StandardErrorPath</key>
    <string>/var/lib/act_runner/act_runner.err</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>/var/lib/act_runner</string>
    </dict>
    <key>UserName</key>
    <string>_act_runner</string>
</dict>
</plist>
EOF

# Set correct permissions
sudo chown root:wheel /Library/LaunchDaemons/com.gitea.act_runner.plist
sudo chmod 644 /Library/LaunchDaemons/com.gitea.act_runner.plist

# Create log directory with correct permissions
sudo mkdir -p /var/lib/act_runner
sudo chown _act_runner:_act_runner /var/lib/act_runner
```

### 4. Start the Service

```bash
# Load the daemon
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist

# Verify the daemon is running
sudo launchctl list | grep act_runner

# Check the logs
tail -f /var/lib/act_runner/act_runner.log
```

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