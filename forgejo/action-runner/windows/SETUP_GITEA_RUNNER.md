# Setting Up Gitea Action Runner on Windows

This guide explains how to set up and manage Gitea Action Runner on Windows using PowerShell scripts.

## Prerequisites

- Windows 10/11 Pro or Windows Server 2019/2022
- PowerShell 5.1 or later
- Administrative privileges
- A running Forgejo/Gitea instance
- Access to Forgejo/Gitea dashboard with admin privileges

## Installation Options

The installation script (`Install.ps1`) provides several actions:

```powershell
.\Install.ps1 [-Action <action>] [-TaskName <name>] [-RunnerVersion <version>] [-Force]

Actions:
  'install-runner'  # Full installation including task scheduler (default)
  'register-task'   # Register the task in Task Scheduler
  'get-status'      # Get task scheduler status
  'remove-task'     # Remove the task scheduler entry
  'update-runner'   # Update the runner binary
```

### Parameters

- `-Action`: Installation action to perform
  - 'install-runner': Performs a full installation (default)
  - 'register-task': Only registers the task scheduler
  - 'get-status': Shows current task status
  - 'remove-task': Removes the task scheduler entry
  - 'update-runner': Updates the runner binary
- `-TaskName`: Custom task name (default: "GiteaActionRunner")
- `-TaskDescription`: Custom task description
- `-RunnerVersion`: Specify runner version (default: "0.2.11")
- `-Force`: Force operation even if components already exist

### Examples

```powershell
# Full installation
.\Install.ps1

# Install with custom task name and version
.\Install.ps1 -TaskName "MyRunner" -RunnerVersion "0.2.12"

# Only register task scheduler
.\Install.ps1 -Action 'register-task'

# Check task status
.\Install.ps1 -Action 'get-status'

# Remove task
.\Install.ps1 -Action 'remove-task'

# Update runner
.\Install.ps1 -Action 'update-runner' -RunnerVersion "0.2.12"
```

## Directory Structure

```
%USERPROFILE%/
├── .cache/
│   ├── actcache/     # Cache directory for actions/cache
│   └── act/          # Work directory for job execution
└── GiteaActionRunner/
    ├── bin/
    │   └── act_runner.exe
    ├── scripts/
    │   ├── Run.ps1           # Runner execution script
    │   └── LogHelpers.psm1   # Shared logging module
    ├── config.yaml   # Runner configuration
    ├── .runner       # Runner registration state
    └── logs/
        ├── install.log
        ├── runner.log        # Current log
        ├── runner.log.1      # Rotated logs
        └── runner.log.2      # Older rotated logs
```

## Configuration

### Runner Configuration (config.yaml)
The `config.yaml` file contains important settings:
- Runner labels (e.g., "windows:host")
- Cache directory settings
- Work directory settings
- Log levels and paths
- Network and security settings

### Runner Script Parameters

Run.ps1 accepts the following parameters:
```powershell
.\scripts\Run.ps1 `
    -InstanceUrl "https://gitea.example.com" `  # Required for registration
    -RegistrationToken "your-token" `           # Required for registration
    -RunnerName "MyRunner" `                    # Optional, defaults to computer name
    -Labels "windows:host,docker" `             # Optional, defaults to "windows:host"
    -ConfigFile "path\to\config.yaml"           # Optional, has default location
```

## Task Scheduler Management

The runner can be managed through Task Scheduler with these features:
- Automatic startup
- Failure recovery (3 retries with 1-minute intervals)
- System privileges
- Network dependency
- Battery operation support

### Task Management Commands

```powershell
# Check task status
.\Install.ps1 -Action 'get-status'

# View detailed status
Get-ScheduledTask -TaskName "GiteaActionRunner" | Select-Object *

# Start the runner
Start-ScheduledTask -TaskName "GiteaActionRunner"

# Stop the runner
Stop-ScheduledTask -TaskName "GiteaActionRunner"

# Remove the task
.\Install.ps1 -Action 'remove-task'
```

## Logging

### Log Files
- Runner logs: `%USERPROFILE%\GiteaActionRunner\logs\runner.log`
- Installation logs: `%USERPROFILE%\GiteaActionRunner\logs\install.log`
- Windows Event Viewer under Task Scheduler logs

### Log Features
- Automatic log rotation (10MB per file)
- Keeps last 5 log files
- Color-coded console output
- Detailed error logging with stack traces
- Debug logging (enable with `$env:GITEA_RUNNER_DEBUG="true"`)

## Security Features

- Task runs with SYSTEM privileges
- Protected configuration files
- Secure token handling
- Comprehensive audit logging
- Network validation
- Error handling security

## Troubleshooting

1. Installation Issues:
   ```powershell
   # Force reinstall
   .\Install.ps1 -Force
   
   # Check installation logs
   Get-Content "$env:USERPROFILE\GiteaActionRunner\logs\install.log"
   ```

2. Task Scheduler Issues:
   ```powershell
   # Check task status
   .\Install.ps1 -Action 'get-status'
   
   # Recreate task
   .\Install.ps1 -Action 'remove-task'
   .\Install.ps1 -Action 'register-task' -Force
   ```

3. Runner Issues:
   ```powershell
   # View live logs
   Get-Content "$env:USERPROFILE\GiteaActionRunner\logs\runner.log" -Wait
   
   # Clear registration and restart
   Remove-Item "$env:USERPROFILE\GiteaActionRunner\.runner"
   .\scripts\Run.ps1 -InstanceUrl "..." -RegistrationToken "..."
   ```

## Best Practices

1. **Installation**:
   - Use specific versions with `-RunnerVersion`
   - Keep installation paths short
   - Use descriptive task names

2. **Maintenance**:
   - Regularly check task status
   - Monitor logs for issues
   - Keep runner updated
   - Clean work directories periodically

3. **Security**:
   - Rotate registration tokens
   - Monitor runner activities
   - Review task permissions
   - Keep system updated

4. **Performance**:
   - Adjust concurrent job capacity
   - Monitor resource usage
   - Configure appropriate timeouts
   - Clean cache periodically