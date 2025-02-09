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
│   ├── start-act-runner-collima.sh       # Colima service startup
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

#### Colima Installation

1. Install and configure Colima:
```bash
brew install colima
```

2. Clean up any existing configurations:
```bash
sudo rm -rf /tmp/colima
sudo rm -f /tmp/colima.yaml

# Create directories
sudo mkdir -p /etc/colima
sudo chown -R _act_runner:_act_runner /etc/colima

# Copy Colima configuration
sudo cp colima/colima.env /etc/colima/
sudo chown _act_runner:_act_runner /etc/colima/colima.env
```

3. Copy and load Colima service:
```bash
sudo cp colima/com.gitea.act_runner.colima.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.colima.plist
```

4. Restart the runner service:
```bash
sudo launchctl unload /Library/LaunchDaemons/com.gitea.act_runner.colima.plist
sudo -u _act_runner DOCKER_HOST=unix:///var/lib/act_runner/.colima/default/docker.sock colima stop
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.colima.plist
```

#### Runner Installation

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

4. Register the runner:
```bash
sudo -u _act_runner act_runner register \
  --instance <instance_url> \
  --token <token> \
  --labels "macos-latest:host"
```

5. Start the runner service:
```bash
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
```

6. Check the status of the runner service:
```bash
sudo launchctl list | grep com.gitea.act_runner
```

7. Restart the runner service:
```bash
sudo launchctl unload /Library/LaunchDaemons/com.gitea.act_runner.plist
sudo launchctl load /Library/LaunchDaemons/com.gitea.act_runner.plist
```

## Option 2: Additional Linux Runner (Inside Colima)

Use this setup when you need:
- Full Docker CLI support in your actions
- Docker-in-Docker capabilities
- Linux-specific features
- Proper file mounting behavior with Docker containers

### Why Use This Option?

This setup addresses several critical limitations when running Docker containers on MacOS through Colima:

1. **File System Mount Behavior**: 
   - Colima VM only mounts the MacOS user's home directory that is used to run Colima into the VM
   - When sharing Docker socket with other users or processes, bind-mounted files must be inside the Colima user's home directory
   - Files outside this directory won't be accessible inside the VM

2. **Docker Mount Issues**: 
   - When running Linux Docker containers on MacOS that use Colima's Docker socket, file mounting can behave unexpectedly
   - Docker tries to mount files from inside the Colima VM's filesystem instead of the MacOS host or Docker container filesystem
   - This can lead to errors like "mount target is a directory" or missing files because the paths don't exist in the VM's filesystem

3. **Solution**:
   - Installing a dedicated act runner inside the Colima VM ensures all file operations happen within the VM's filesystem
   - File mounts in Docker containers work correctly because both the runner and Docker daemon share the same filesystem
   - Eliminates path translation issues between MacOS and Linux environments

This setup is particularly important when your workflows involve:
- Mounting local directories into containers
- Building Docker images with local context
- Running complex Docker Compose setups
- Working with file-heavy operations in containers

### Installation Steps

1. Install requirements tools for Runner in Colima VM: unzip, git-lfs

2. Setup and Install Linux runner:
- Follow [this guide](../linux/README.md) to install and configure the Linux runner

3. Register the Linux runner:
```bash
# Register with Forgejo
sudo -u _act_runner colima ssh "sudo -u act_runner /usr/local/bin/act_runner register \
  --no-interactive \
  --instance <instance_url> \
  --token <token> \
  --name <runner_name> \
  --labels 'ubuntu-latest:docker://gitea/runner-images:ubuntu-latest'"
```

4. Install Linux runner service:
```bash
# Copy service template
sudo -u _act_runner colima ssh "cat > /opt/act_runner/act_runner.service" < act_runner/act_runner.service
sudo -u _act_runner colima ssh "sudo mv /opt/act_runner/act_runner.service /etc/systemd/system/"
```

5. Start the runner service:
```bash
sudo -u _act_runner colima ssh "sudo systemctl daemon-reload"
sudo -u _act_runner colima ssh "sudo systemctl enable --now act_runner"
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
- Check Colima status: `sudo -u _act_runner DOCKER_HOST=unix:///var/lib/act_runner/.colima/default/docker.sock colima status`
- Check service status: `sudo launchctl list | grep act_runner`
- View logs: `sudo tail -f /var/lib/act_runner/log/act_runner.log`

### Linux Runner
- Check runner status: `sudo -u _act_runner DOCKER_HOST=unix:///var/lib/act_runner/.colima/default/docker.sock colima ssh "systemctl status act_runner"`
- View logs: `sudo -u _act_runner DOCKER_HOST=unix:///var/lib/act_runner/.colima/default/docker.sock colima ssh "journalctl -u act_runner -f"`
- Check Docker access: `sudo -u _act_runner DOCKER_HOST=unix:///var/lib/act_runner/.colima/default/docker.sock colima ssh "sudo -u act_runner docker ps"`

## References
- [[202501061959 Set up MacOS as private server with Tailscale and Docker]]
- [Gitea Action Runner Documentation](https://docs.gitea.com/usage/actions/act-runner)
- [Colima - Container Runtime for macOS](https://github.com/abiosoft/colima)
- [MacOS Daemon Management](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [Docker Engine Installation](https://docs.docker.com/engine/install/)