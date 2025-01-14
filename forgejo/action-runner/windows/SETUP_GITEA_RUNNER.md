# Setting Up Gitea Action Runner on Windows

This guide explains how to set up and manage Gitea Action Runner on Windows using PowerShell scripts.

## Prerequisites

- Windows 10/11 Pro or Windows Server 2019/2022
- PowerShell 5.1 or later
- Administrative privileges (only for system-wide installation)
- A running Forgejo/Gitea instance
- Access to Forgejo/Gitea dashboard with admin privileges

## Installation Options

The installation script (`Install.ps1`) provides several actions:

```powershell
.\Install.ps1 [-Action <action>] [-TaskName <name>] [-InstallSpace <space>] [-RunnerVersion <version>] [-Force]

Actions:
  help           Show help message (default)
  install-runner Install the runner and register task scheduler
  register-task  Register the task in Task Scheduler
  get-status     Get task scheduler status
  remove-task    Remove the task scheduler entry
  update-runner  Update the runner binary
```

### Parameters

- `-Action`: Installation action to perform
  - `help`: Show help message (default)
  - `install-runner`: Performs a full installation
  - `register-task`: Only registers the task scheduler
  - `get-status`: Shows current task status
  - `remove-task`: Removes the task scheduler entry
  - `update-runner`: Updates the runner binary
- `-TaskName`: Custom task name (default: "GiteaActionRunner")
- `-TaskDescription`: Custom task description
- `-RunnerVersion`: Specify runner version (default: "0.2.11")
- `-InstallSpace`: Installation space (default: "system")
  - `system`: System-wide installation (requires admin)
  - `user`: User space installation (no admin required)
- `-Force`: Force operation even if components already exist

### Installation Spaces

The script supports two installation spaces:

1. System-wide Installation (`-InstallSpace system`):
   - Requires administrative privileges
   - Program files in `%ProgramFiles%\GiteaActRunner`
   - Data files in `%ProgramData%\GiteaActRunner`
   - Shared by all users
   - Better security isolation

2. User Space Installation (`-InstallSpace user`):
   - No administrative privileges required
   - All files in user's home directory
   - Program files in `%USERPROFILE%\.gitea\act_runner\bin`
   - Data files in `%USERPROFILE%\.gitea\act_runner\data`
   - Per-user isolation
   - Portable installation

### Administrative Requirements

- System-wide Installation (`-InstallSpace system`):
  - `install-runner`: Requires admin
  - `register-task`: Requires admin
  - `get-status`: No admin required
  - `remove-task`: Requires admin
  - `update-runner`: Requires admin

- User Space Installation (`-InstallSpace user`):
  - No admin privileges required for any action
  - All operations within user's home directory

### Examples

```powershell
# Show help
.\Install.ps1
.\Install.ps1 -Action help

# System-wide installation (requires admin)
.\Install.ps1 -Action install-runner -InstallSpace system

# User space installation (no admin required)
.\Install.ps1 -Action install-runner -InstallSpace user

# Install with custom task name and version
.\Install.ps1 -TaskName "MyRunner" -RunnerVersion "0.2.12"

# Only register task scheduler
.\Install.ps1 -Action register-task

# Check task status (no admin required)
.\Install.ps1 -Action get-status

# Remove task
.\Install.ps1 -Action remove-task

# Update runner
.\Install.ps1 -Action update-runner -RunnerVersion "0.2.12"
```

## Directory Structure

### System-wide Installation (`-InstallSpace system`)

```
%ProgramFiles%\GiteaActRunner\     # Program files (requires admin)
├── bin\
│   └── act_runner.exe            # Runner binary
└── scripts\
    ├── Run.ps1                   # Runner execution script
    └── LogHelpers.psm1           # Shared logging module

%ProgramData%\GiteaActRunner\      # Program data
├── config.yaml                   # Runner configuration
├── .runner                       # Runner registration state
├── logs\
│   ├── install.log              # Installation logs
│   ├── runner.log               # Current log
│   ├── runner.log.1             # Rotated logs
│   └── runner.log.2             # Older rotated logs
├── cache\
│   └── actcache\                # Cache directory for actions
└── work\                        # Work directory for job execution
```

### User Space Installation (`-InstallSpace user`)

```
%USERPROFILE%\.gitea\act_runner\
├── bin\                         # Program files
│   ├── bin\
│   │   └── act_runner.exe      # Runner binary
│   └── scripts\
│       ├── Run.ps1             # Runner execution script
│       └── LogHelpers.psm1     # Shared logging module
└── data\                       # Program data
    ├── config.yaml             # Runner configuration
    ├── .runner                 # Runner registration state
    ├── logs\
    │   ├── install.log         # Installation logs
    │   └── runner.log          # Runner logs
    ├── cache\
    │   └── actcache\          # Cache directory
    └── work\                   # Work directory
```

## Configuration

### Runner Configuration (config.yaml)
The `config.yaml` file in ProgramData contains important settings:
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
# Check task status (no admin required)
.\Install.ps1 -Action get-status

# View detailed status
Get-ScheduledTask -TaskName "GiteaActionRunner" | Select-Object *

# Start the runner
Start-ScheduledTask -TaskName "GiteaActionRunner"

# Stop the runner
Stop-ScheduledTask -TaskName "GiteaActionRunner"

# Remove the task (requires admin)
.\Install.ps1 -Action remove-task
```

## Logging

### Log Files
- Runner logs: `%ProgramData%\GiteaActRunner\logs\runner.log`
- Installation logs: `%ProgramData%\GiteaActRunner\logs\install.log`
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
   # Force reinstall (run as administrator)
   .\Install.ps1 -Force
   
   # Check installation logs
   Get-Content "$env:ProgramData\GiteaActRunner\logs\install.log"
   ```

2. Task Scheduler Issues:
   ```powershell
   # Check task status
   .\Install.ps1 -Action get-status
   
   # Recreate task (run as administrator)
   .\Install.ps1 -Action remove-task
   .\Install.ps1 -Action register-task -Force
   ```

3. Runner Issues:
   ```powershell
   # View live logs
   Get-Content "$env:ProgramData\GiteaActRunner\logs\runner.log" -Wait
   
   # Clear registration and restart
   Remove-Item "$env:ProgramData\GiteaActRunner\.runner"
   .\scripts\Run.ps1 -InstanceUrl "..." -RegistrationToken "..."
   ```

## Best Practices

1. **Installation**:
   - Run installation commands as administrator
   - Use specific versions with `-RunnerVersion`
   - Keep installation paths default
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