# Setting Up Gitea Action Runner on MacOS for Forgejo Instance

This guide explains how to set up Gitea Action Runner on MacOS to work with a Forgejo instance, since Forgejo Actions currently doesn't support MacOS and Windows hosts natively.

## Quick Start

1. Check your system architecture:
   ```bash
   ./act_runner/check_arch.sh
   ```

2. Install the runner:
   ```bash
   sudo ./act_runner/install.sh
   ```

3. Create system user:
   ```bash
   sudo ./act_runner/create_user.sh
   ```

4. Configure Docker (Option 2 recommended):
   ```bash
   sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.colima.plist
   ```

5. Start the runner:
   ```bash
   sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
   ```

## Prerequisites

- MacOS operating system
- Administrative privileges (sudo access)
- A running Forgejo instance
- Access to Forgejo dashboard with admin privileges

## Project Structure

```
macos/
├── act_runner/           # Core runner components
│   ├── check_arch.sh     # CPU architecture detection
│   ├── create_user.sh    # System user creation
│   ├── install.sh        # Runner installation
│   ├── config.yaml       # Runner configuration
│   ├── com.gitea.act_runner.plist    # Main service config
│   ├── nvm.sh           # Node.js setup
│   ├── pyenv.sh         # Python setup
│   └── start_act_runner.sh   # Service startup
├── actions/             # Example workflows
│   └── test.yaml        # Test workflow template
└── colima/             # Docker setup components
    ├── colima.env       # Environment variables
    ├── com.gitea.act_runner.plist  # Service config
    └── start-act-runner-colima.sh  # Startup script
```

## References

- [Gitea Action Runner Documentation](https://docs.gitea.com/usage/actions/act-runner)
- [Colima - Container Runtime for macOS](https://github.com/abiosoft/colima)
- [MacOS Daemon Management](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [Docker Engine Installation](https://docs.docker.com/engine/install/)
- [Related: Setting up MacOS as Private Server](202501061959%20Set%20up%20MacOS%20as%20private%20server%20with%20Tailscale%20and%20Docker)

## System Architecture

### MacOS Daemon Management
MacOS uses `launchd` as its system-wide daemon manager, started by the kernel during boot. Key points:
- Daemons run in system context with one instance for all clients
- System daemons use underscore prefix (e.g., `_act_runner`)
- System UIDs should be below 1024 (we use 385)
- Configuration files live in `/Library/LaunchDaemons/`

### Finding Available System IDs
Before creating a new daemon user, find available system IDs:
```bash
# List last used group IDs
dscacheutil -q group | grep gid | awk '{print $2}' | sort -n | tail -n 15

# Or just get the highest used GID
dscacheutil -q group | grep gid | awk '{print $2}' | sort -n | tail -n 1
```

### Runner Architecture
The runner operates as a system daemon with these components:
1. System User: `_act_runner` for isolation
2. Service Configuration: LaunchDaemon plists
3. Docker Integration: Via Colima
4. Environment Setup: Node.js and Python support

## Detailed Setup Steps

### 1. System Architecture Check
The [check_arch.sh](act_runner/check_arch.sh) script determines your CPU architecture:
- Detects Apple M-series vs Intel
- Recommends appropriate binary version
- Handles Rosetta 2 detection

### 2. Runner Installation
[install.sh](act_runner/install.sh) handles binary installation:
- Downloads correct architecture version
- Sets up executable permissions
- Installs to system path

### 3. System User Creation
[create_user.sh](act_runner/create_user.sh) sets up the system daemon user:
- Creates `_act_runner` user and group
- Sets up home and config directories
- Configures proper permissions

### 4. Docker Configuration

#### Option 1: Share Existing Colima Instance
Use when you want to share Docker resources:

1. Find the existing Colima Docker socket:
```bash
# Get socket location from Colima status
colima status

# Default location is in user's home directory
ls -l /Users/COLIMA_USER/.colima/default/docker.sock
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
```

4. Test Docker access:
```bash
sudo -u _act_runner bash -c 'source /etc/act_runner/environment && docker ps'
```

Note: Replace `COLIMA_USER` with the actual username running Colima.

#### Option 2: Dedicated Colima Instance (Recommended)
Provides better isolation and security:
1. Configure using [colima.env](colima/colima.env)
2. Set up service with [com.gitea.act_runner.plist](colima/com.gitea.act_runner.plist)
3. Start using [start-act-runner-colima.sh](colima/start-act-runner-colima.sh)

**Benefits:**
- Isolated Docker environment
- Dedicated resources
- Better security
- Independent lifecycle

**Setup Steps:**
1. Apply configurations from `colima/` directory
2. Start Colima service:
   ```bash
   sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.colima.plist
   ```

### 5. Runner Service Setup
1. Load service configuration:
   ```bash
   sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
   ```

2. Verify service status:
   ```bash
   sudo launchctl list | grep act_runner
   ```

## Testing Your Setup

1. Deploy test workflow:
   ```bash
   cp actions/test.yaml /path/to/your/repo/.forgejo/workflows/
   ```

2. Monitor execution:
   ```bash
   sudo tail -f /var/log/act_runner.log
   ```

## Troubleshooting Guide

### Service Issues
Common problems and solutions:
- Status Check: `sudo launchctl list | grep act_runner`
- Log Review: `sudo tail -f /var/log/act_runner.log`
- Permission Check: `ls -la /var/lib/act_runner /etc/act_runner`

### Docker Issues
Verify Docker setup:
- Colima Status: `sudo -u _act_runner HOME=/var/lib/act_runner colima status`
- Docker Access: `sudo -u _act_runner docker ps`
- Socket Check: `ls -l /var/lib/act_runner/.colima/default/docker.sock`

### Network Issues
Connectivity problems:
- Basic Connectivity: `ping -c 1 1.1.1.1`
- DNS Resolution: `nslookup forgejo.yourdomain`
- Registration: Verify runner token and instance URL

### Security Checks
Verify system security:
```bash
# Check user settings
sudo dscl . -read /Users/_act_runner

# Verify login window settings
sudo defaults read /Library/Preferences/com.apple.loginwindow | grep _act_runner && \
echo "❌ Warning: User appears in login window" || \
echo "✓ User hidden from login window"

# Check file permissions
ls -la /var/lib/act_runner
ls -la /etc/act_runner
ls -la /Library/LaunchDaemons/com.gitea.act_runner.plist
```

## Maintenance

### Updating the Runner
1. Stop the service:
   ```bash
   sudo launchctl unload /Library/LaunchDaemons/com.gitea.act_runner.plist
   ```

2. Run installation script:
   ```bash
   sudo ./act_runner/install.sh
   ```

3. Restart service:
   ```bash
   sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
   ```

### Logs and Monitoring
- Service Logs: `/var/log/act_runner.log`
- Colima Logs: `/var/lib/act_runner/.colima/default/colima.log`
- System Logs: `sudo log show --predicate 'process == "act_runner"'`

### Backup and Recovery
Important files to backup:
- Configuration: `/etc/act_runner/`
- Service Files: `/Library/LaunchDaemons/com.gitea.act_runner.plist`
- Runner Data: `/var/lib/act_runner/`
- Logs: `/var/log/act_runner.log`
