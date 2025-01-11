# Windows Gitea Action Runner

A Windows-based Docker container for running Gitea Actions.

## References

- [Gitea Runner](https://gitea.com/gitea/act_runner)
- [Runner Configuration](https://gitea.com/gitea/act_runner/src/branch/main/docs/configuration.md)
- [Run Script](https://gitea.com/gitea/act_runner/raw/branch/main/scripts/run.sh)

## Features

- Windows Server Core base image
- Persistent application installation
- Automatic runner registration with retry logic
- Support for Visual Studio tools
- Graceful shutdown handling
- Secure token management
- Color-coded logging (INFO: white, ERROR: red)
- Comprehensive error handling

## Environment Variables

### Required Variables
- `GITEA_INSTANCE_URL`: URL of your Gitea instance
- `GITEA_RUNNER_REGISTRATION_TOKEN`: Runner registration token
  - Alternatively, use `GITEA_RUNNER_REGISTRATION_TOKEN_FILE` to read token from a file (e.g., Docker Secret)

### Optional Variables
- `GITEA_RUNNER_NAME`: Name of the runner (default: hostname)
- `GITEA_RUNNER_LABELS`: Runner labels (default: windows:host)
- `CONFIG_FILE`: Custom config file path
- `RUNNER_STATE_FILE`: Custom path for runner state file (default: .runner)
- `GITEA_MAX_REG_ATTEMPTS`: Maximum registration attempts (default: 10)

### Security Notes
- Registration token is automatically removed from environment after successful registration
- Token file remains accessible for container restarts
- Sensitive data is logged only at ERROR level
- Environment variables are validated before use

### Default Paths
The runner uses these default paths:
- Runner state file: `.runner` in runner's working directory (can be overridden with `RUNNER_STATE_FILE`)
- Cache: `.cache/actache` in runner's working directory
- Work directory: `.cache/act` in runner's working directory

### Logging Levels
- `INFO` (White): Normal operational messages
- `ERROR` (Red): Error messages that may affect operation

## Usage

1. Create a `.env` file with your Gitea instance details:
```env
GITEA_INSTANCE_URL=http://your-forgejo-instance:3000
GITEA_RUNNER_REGISTRATION_TOKEN=your-runner-token
# OR use token file
# GITEA_RUNNER_REGISTRATION_TOKEN_FILE=/run/secrets/runner-token
```

2. Start the runner:
```bash
docker compose up -d
```

## Visual Studio Tools

To use Visual Studio tools, uncomment the relevant volume mounts in `docker-compose.yaml`:
```yaml
volumes:
  - "C:\\Program Files (x86)\\Windows Kits:C:\\Program Files (x86)\\Windows Kits"
  - "C:\\Program Files (x86)\\Microsoft Visual Studio:C:\\Program Files (x86)\\Microsoft Visual Studio"
  - "C:\\Program Files\\Microsoft Visual Studio:C:\\Program Files\\Microsoft Visual Studio"
  - "C:\\ProgramData\\Microsoft\\VisualStudio:C:\\ProgramData\\Microsoft\\VisualStudio"
```

And uncomment the Visual Studio installation in `Dockerfile`:
```dockerfile
# choco install visualstudio2022-workload-vctools --no-progress -y
```

## Customization

### Custom Paths
You can override default paths using environment variables:
```yaml
environment:
  - CONFIG_FILE=C:\custom\path\config.yaml
  - RUNNER_STATE_FILE=C:\custom\path\.runner
```

### Resource Limits
Adjust container resources in `docker-compose.yaml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
    reservations:
      cpus: '0.5'
      memory: 1G
```

## Container Lifecycle

- Container starts with the act_runner process
- Automatic registration on first run with retry logic
- Container stops when act_runner process exits
- Automatic restart with `restart: unless-stopped` policy
- Registration state persists across restarts