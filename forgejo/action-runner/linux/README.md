# Setup Gitea/Forgejo Action Runner on Linux

This guide explains how to set up a Gitea/Forgejo Action Runner on a Linux system. The setup process is divided into several scripts for better maintainability and flexibility.

## Directory Structure

```
.
├── README.md
├── scripts/
│   ├── install_act_runner.sh    # Script to download and install the binary
│   ├── setup_system.sh          # Script to setup system user and config
│   ├── setup_service.sh         # Script to setup systemd service
│   └── install_nodejs.sh        # Script to install NodeJS and pnpm
├── templates/
│   ├── config.yaml             # Runner configuration template
│   └── act_runner.service      # Systemd service template
```

## Prerequisites

- Linux system with systemd
- Docker (optional, but recommended)
- Root or sudo access
- curl and basic system utilities

## Installation Methods

### Method 1: Quick Setup (Recommended)

For a quick setup, use the provided scripts in the `scripts` directory:

1. Make scripts executable:
```bash
chmod +x scripts/*.sh
```

2. Run installation scripts in order:
```bash
# 1. Install act runner binary
./scripts/install_act_runner.sh

# 2. Setup system user and configuration
./scripts/setup_system.sh

# 3. Setup systemd service
./scripts/setup_service.sh

# 4. Install NodeJS, fnm, and pnpm
./scripts/install_nodejs.sh
```

### Method 2: Manual Installation

If you prefer manual installation or need customization, refer to the scripts in the `scripts` directory for the exact commands. Each script is well-documented and can be executed step by step.

## Post-Installation Setup

### 1. Register Runner

Before starting the service, register the runner with your Gitea/Forgejo instance:

```bash
# Switch to act_runner user
sudo -u act_runner -s

# Register the runner (interactive mode)
act_runner register --config /etc/act_runner/config.yaml

# Exit act_runner user shell
exit
```

During registration, you will need:
- Instance URL (e.g., https://gitea.yourdomain.com)
- Registration token (from your instance's Actions settings)
- Runner name (optional, defaults to hostname)
- Runner labels (optional)

### 2. Start and Enable Service

```bash
# Enable and start the service
sudo systemctl enable --now act_runner

# Verify the service is running
sudo systemctl status act_runner
```

## Configuration

### Template Files

The setup uses two template files:

1. `templates/config.yaml`: Runner configuration
   - Log settings
   - Runner capacity and file locations
   - Cache configuration
   - Container settings

2. `templates/act_runner.service`: Systemd service configuration
   - Service dependencies
   - Execution parameters
   - Restart policies
   - User permissions

### Important Paths

- Binary: `/usr/local/bin/act_runner`
- Configuration: `/etc/act_runner/config.yaml`
- Working Directory: `/var/lib/act_runner`
- Logs: `/var/lib/act_runner/log/act_runner.log`
- Runner State: `/var/lib/act_runner/.runner`
- Cache Directory: `/var/lib/act_runner/cache`

## Maintenance

### Service Management

```bash
# View service status
sudo systemctl status act_runner

# View live logs
sudo journalctl -u act_runner -f

# Restart service
sudo systemctl restart act_runner

# Stop service
sudo systemctl stop act_runner
```

### Updating Runner

To update the act runner binary:

1. Stop the service:
```bash
sudo systemctl stop act_runner
```

2. Download and replace the binary:
```bash
sudo curl -L "https://dl.gitea.com/act_runner/[VERSION]/act_runner-[VERSION]-linux-[ARCH]" -o /usr/local/bin/act_runner
sudo chmod +x /usr/local/bin/act_runner
```

3. Restart the service:
```bash
sudo systemctl restart act_runner
```

## Troubleshooting

### Common Issues

1. Service fails to start:
   - Check logs: `sudo journalctl -u act_runner -f`
   - Verify permissions: `ls -la /var/lib/act_runner`
   - Check configuration: `sudo -u act_runner act_runner --config /etc/act_runner/config.yaml daemon`

2. Runner not connecting:
   - Verify network connectivity to Gitea instance
   - Check registration token
   - Ensure correct URL in registration

3. Actions failing with NodeJS errors:
   - Verify NodeJS installation: `node --version`
   - Check pnpm installation: `pnpm --version`
   - Ensure act_runner user has access to NodeJS

### Logs and Debugging

1. Service logs:
```bash
# View all logs
sudo journalctl -u act_runner

# View recent logs
sudo journalctl -u act_runner -n 100

# Follow new logs
sudo journalctl -u act_runner -f
```

2. Runner logs:
```bash
# View runner log file
sudo tail -f /var/lib/act_runner/log/act_runner.log
```

## Security Notes

- The act_runner user having docker group membership effectively grants root access through Docker
- Keep your runner token secure and never share it
- Regularly update the act_runner binary to get security patches
- Consider network security implications when running actions

## References

1. [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/overview)
2. [Gitea Act Runner Documentation](https://docs.gitea.com/usage/actions/act-runner)
3. [NodeJS Download](https://nodejs.org/en/download)
4. [Fast Node Manager (fnm)](https://github.com/Schniz/fnm)
5. [PNPM Documentation](https://pnpm.io/installation)
6. [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
7. [Docker Post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)