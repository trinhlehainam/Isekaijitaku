# Windows Gitea Action Runner

A Windows container-based runner for Gitea Actions.

## Prerequisites

- Windows 10/11 or Windows Server with Docker support
- Docker Desktop set to Windows containers
- PowerShell 5.1 or later

## Quick Start

1. Create `.env` file:
```env
GITEA_INSTANCE_URL=http://gitea:3000
GITEA_RUNNER_REGISTRATION_TOKEN=your_token_here
```

2. Build and run:
```powershell
# Build with specific Gitea runner version
docker compose build --build-arg gitea_runner_version=0.2.11

# Start the runner
docker compose up -d
```

## Configuration

### Environment Variables

Required:
- `GITEA_INSTANCE_URL`: URL of your Gitea instance
- `GITEA_RUNNER_REGISTRATION_TOKEN`: Runner registration token

Optional:
- `GITEA_RUNNER_NAME`: Name for the runner (default: hostname)
- `GITEA_RUNNER_LABELS`: Labels for the runner (default: windows:host)
- `CONFIG_FILE`: Custom config file path
- `GITEA_MAX_REG_ATTEMPTS`: Maximum registration attempts (default: 10)

### Build Arguments

- `gitea_runner_version`: Version of Gitea runner to install (e.g., "0.2.11")

### Security Notes
- Registration token is automatically removed from environment after successful registration
- Token file remains accessible for container restarts
- Environment variables are validated before use
- TLS certificate verification enabled by default

### Default Paths
- Runner state file: `.runner` in runner's working directory (can be overridden with `RUNNER_STATE_FILE`)
- Cache directory: `$HOME/.cache/actcache` if not specified in config
- Work directory: `$HOME/.cache/act` if not specified in config
- Config file: `config.yaml` in runner's working directory

> Note: In Windows Server Core container, `$HOME` is `C:\Users\ContainerAdministrator`

### Runner Configuration

The runner uses a configuration file (`config.yaml`) with the following key settings:

```yaml
log:
  level: info  # Logging level: trace, debug, info, warn, error, fatal

runner:
  file: .runner  # Registration state file
  capacity: 1    # Concurrent task limit
  timeout: 3h    # Job execution timeout
  shutdown_timeout: 3h  # Graceful shutdown timeout
  insecure: false  # TLS verification
  fetch_timeout: 5s  # Job fetch timeout
  fetch_interval: 2s  # Job fetch interval
  report_interval: 1s  # Status report interval
  labels:  # Runner capabilities
    - "windows:host"

cache:
  enabled: true
  dir: .cache
  host: ""
  port: 0
```

### Example Configuration

#### docker-compose.yaml
```yaml
services:
  gitea-runner:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        gitea_runner_version: 0.2.11
    image: gitea-runner-windows:0.2.11
    environment:
      - GITEA_INSTANCE_URL=http://gitea:3000
      - GITEA_RUNNER_REGISTRATION_TOKEN=your_token_here
      - GITEA_RUNNER_NAME=windows-container-gitea-runner
      - GITEA_RUNNER_LABELS=windows:host
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
    restart: unless-stopped
```

### Resource Management

Windows containers support resource limits but not reservations. Setting memory reservations will result in the error:
```
Error response from daemon: invalid option: Windows does not support MemoryReservation
```

You can set resource limits in `docker-compose.yaml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
```

## Commands

### Build and Run

```powershell
# Build with specific version
docker compose build --build-arg gitea_runner_version=0.2.11

# Build with specific version and tag
docker compose build --build-arg gitea_runner_version=0.2.11 gitea-runner

# Start runner
docker compose up -d

# View logs
docker compose logs -f

# Stop runner
docker compose down
```

### Maintenance

```powershell
# View runner status
docker compose ps

# View detailed logs
docker compose logs -f --tail=100

# Restart runner
docker compose restart

# Update to latest version
docker compose pull
docker compose up -d
```

## Troubleshooting

### Common Issues

1. Build fails:
   - Ensure Docker Desktop is set to Windows containers
   - Try rebuilding without cache: `docker compose build --no-cache`
   - Check build logs for specific errors

2. Runner fails to start:
   - Verify environment variables in `.env` or `docker-compose.yaml`
   - Check Gitea instance URL is accessible
   - Ensure registration token is valid
   - View logs: `docker compose logs -f`

3. Runner registration fails:
   - Check network connectivity to Gitea instance
   - Verify registration token hasn't expired
   - Check for any proxy or firewall issues

### Logs

View runner logs:
```powershell
# Follow logs
docker compose logs -f

# View last N lines
docker compose logs --tail=100

# View logs for specific time
docker compose logs --since 30m