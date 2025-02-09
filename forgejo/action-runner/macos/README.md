# Setting Up Gitea Action Runner on MacOS for Forgejo Instance

This guide explains how to set up Gitea Action Runner on MacOS to work with a Forgejo instance. There are two setup options:

1. **MacOS Host Runner**: Runs directly on macOS with Colima providing Docker functionality
2. **Additional Linux Runner**: Runs inside the same Colima VM with full Docker CLI support

## Prerequisites

- MacOS operating system
- Administrative privileges (sudo access)
- A running Forgejo instance
- Access to Forgejo dashboard with admin privileges
- Homebrew package manager

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
├── colima/              # Colima configurations
│   ├── colima.env       # Colima environment configuration
│   └── com.gitea.act_runner.colima.plist    # Colima service config
└── actions/             # Test actions
    └── test.yaml        # Test workflow
```

## Option 1: MacOS Host Runner

Use this setup when you want to:
- Run actions directly on macOS host
- Use Docker functionality through Colima
- Run Linux containers without needing Docker CLI inside actions

### Installation Steps

1. Install and configure Colima:
```bash
# Install Colima
brew install colima

# Create directories
sudo mkdir -p /opt/act_runner/colima
sudo chown -R _act_runner:_act_runner /opt/act_runner

# Copy Colima configuration
sudo cp colima/colima.env /opt/act_runner/colima/
sudo chown _act_runner:_act_runner /opt/act_runner/colima/colima.env

# Copy and load Colima service
sudo cp colima/com.gitea.act_runner.colima.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.colima.plist

# Wait for Colima to start
sleep 10
```

2. Check your system architecture:
```bash
./act_runner/check_arch.sh
```

3. Install the runner:
```bash
sudo ./act_runner/install.sh
```

4. Create system user:
```bash
sudo ./act_runner/create_user.sh
```

5. Configure Docker access for act_runner:
```bash
# Create docker group if it doesn't exist
sudo dscl . -create /Groups/docker
sudo dscl . -create /Groups/docker PrimaryGroupID 1001
sudo dscl . -create /Groups/docker GroupMembership _act_runner

# Set environment for act_runner
sudo mkdir -p /etc/act_runner
sudo tee /etc/act_runner/environment << EOF
DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
EOF
sudo chown -R _act_runner:_act_runner /etc/act_runner
```

6. Start the runner service:
```bash
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
```

7. Register the runner:
```bash
sudo -u _act_runner act_runner register \
  --instance <instance_url> \
  --token <token> \
  --labels "macos-latest:host"
```

## Option 2: Additional Linux Runner (Inside Colima)

Use this setup when you need:
- Full Docker CLI support in your actions
- Docker-in-Docker capabilities
- Linux-specific features

This setup installs an additional act_runner service inside the existing Colima VM that's used by the MacOS runner.

### Installation Steps

1. Copy Linux setup files to Colima VM:
```bash
# Create directory in Colima VM
colima ssh "sudo mkdir -p /opt/act_runner"

# Copy Linux setup files
colima ssh "cat > /opt/act_runner/install_act_runner.sh" < ../linux/scripts/install_act_runner.sh
colima ssh "cat > /opt/act_runner/setup_system.sh" < ../linux/scripts/setup_system.sh
colima ssh "cat > /opt/act_runner/config.yaml" < ../linux/templates/config.yaml
colima ssh "sudo chmod +x /opt/act_runner/*.sh"
```

2. Install and configure Linux runner:
```bash
# Run installation scripts
colima ssh "cd /opt/act_runner && sudo ./install_act_runner.sh"
colima ssh "cd /opt/act_runner && sudo ./setup_system.sh"

# Copy service template
colima ssh "cat > /opt/act_runner/act_runner.service" < ../linux/templates/act_runner.service
colima ssh "sudo mv /opt/act_runner/act_runner.service /etc/systemd/system/"

# Start service
colima ssh "sudo systemctl daemon-reload"
colima ssh "sudo systemctl enable --now act_runner"
```

3. Register the Linux runner:
```bash
# Register with Forgejo
colima ssh "sudo -u act_runner /usr/local/bin/act_runner register \
  --instance <instance_url> \
  --token <token> \
  --labels 'ubuntu-latest:docker://gitea/runner-images:ubuntu-latest'"
```

### Managing Multiple Runners

You can run both runners simultaneously. They will appear as separate runners with different labels:
- MacOS runner: `macos-latest:host`
- Linux runner: `ubuntu-latest:host`

Example workflow using both runners:
```yaml
jobs:
  macos-build:
    runs-on: macos-latest    # Uses MacOS host runner
    steps:
      - uses: actions/checkout@v3
      - run: ./build.sh       # Runs directly on macOS

  linux-docker-build:
    runs-on: ubuntu-latest   # Uses Linux runner inside Colima
    steps:
      - uses: actions/checkout@v3
      - run: docker build .   # Has access to Docker CLI
```

## Troubleshooting

### MacOS Host Runner
- Check Colima status: `colima status`
- Check service status: `sudo launchctl list | grep act_runner`
- View logs: `sudo tail -f /var/lib/act_runner/log/act_runner.log`

### Linux Runner
- Check runner status: `colima ssh "systemctl status act_runner"`
- View logs: `colima ssh "journalctl -u act_runner -f"`
- Check Docker access: `colima ssh "sudo -u act_runner docker ps"`

## References
- [[202501061959 Set up MacOS as private server with Tailscale and Docker]]
- [Gitea Action Runner Documentation](https://docs.gitea.com/usage/actions/act-runner)
- [Colima - Container Runtime for macOS](https://github.com/abiosoft/colima)
- [MacOS Daemon Management](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [Docker Engine Installation](https://docs.docker.com/engine/install/)