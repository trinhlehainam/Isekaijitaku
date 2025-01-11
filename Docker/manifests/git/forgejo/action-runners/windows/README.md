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
- Resource limits and reservations

## Configuration

### Required Environment Variables

- `GITEA_INSTANCE_URL`: URL of your Gitea instance
- `GITEA_RUNNER_REGISTRATION_TOKEN`: Runner registration token
  - Alternatively, use `GITEA_RUNNER_REGISTRATION_TOKEN_FILE` to read token from a file (e.g., Docker Secret)

### Optional Environment Variables

- `GITEA_RUNNER_NAME`: Name of the runner (default: hostname)
- `GITEA_RUNNER_LABELS`: Runner labels (default: windows:host)
- `CONFIG_FILE`: Custom config file path
- `RUNNER_STATE_FILE`: Custom path for runner state file (default: .runner)
- `GITEA_MAX_REG_ATTEMPTS`: Maximum registration attempts (default: 10)

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

Note: In Windows Server Core container, `$HOME` is `C:\Users\ContainerAdministrator`

### Logging Levels

- `INFO` (White): Normal operational messages
- `ERROR` (Red): Error messages that may affect operation

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
    - "windows-latest:host"
    - "windows-server-2022:host"

cache:
  enabled: true
  dir: .cache
  host: ""
  port: 0
```

### Container Health Check

The container includes a health check that verifies runner registration:
- Interval: 30s
- Timeout: 10s
- Retries: 3
- Start period: 30s

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

## Usage

1. Create a `docker-compose.yaml` file:
   ```yaml
   services:
     gitea-runner:
       build:
         context: .
         dockerfile: Dockerfile
       environment:
         - GITEA_INSTANCE_URL=http://your-forgejo-instance:3000
         - GITEA_RUNNER_REGISTRATION_TOKEN=your-runner-token
         - GITEA_RUNNER_NAME=windows-container-gitea-runner
       volumes:
         - ./runner:/data
       deploy:
         resources:
           limits:
             cpus: '2'
             memory: 4G
       restart: unless-stopped
   ```

2. Start the runner:
   ```powershell
   docker-compose up -d
   ```
   
3. Check the logs:
   ```powershell
   docker-compose logs -f
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
```

## Container Lifecycle

- Container starts with the act_runner process
- Automatic registration on first run with retry logic
- Container stops when act_runner process exits
- Automatic restart with `restart: unless-stopped` policy
- Registration state persists across restarts

## Troubleshooting

1. If registration fails:
   - Check the instance URL is accessible
   - Verify the registration token is valid
   - Check network connectivity
   - Review logs for specific error messages

2. If jobs fail:
   - Check resource limits
   - Verify required tools are installed
   - Check network access to required resources
   - Review job logs for error messages