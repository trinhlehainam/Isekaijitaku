# Setting Up Gitea Action Runner on Windows

This guide explains how to set up and manage Gitea Action Runner on Windows using PowerShell scripts.

## Prerequisites

- Windows 10/11 Pro or Windows Server 2019/2022
- PowerShell 5.1 or later
- Administrative privileges (only for system-wide installation)
- A running Forgejo/Gitea instance
- Access to Forgejo/Gitea dashboard with admin privileges

## Setup Options

The setup script (`Setup.ps1`) provides several actions:

```powershell
.\Setup.ps1 [-Action <action>] [-TaskName <name>] [-InstallSpace <space>] [-RunnerVersion <version>] [-Force]

Actions:
  help            Show help message (default)
  install         Install the runner and register task scheduler
  register        Register the task in Task Scheduler
  status          Get task scheduler status
  unregister      Remove the task scheduler entry
  update          Update the runner binary
  uninstall       Remove runner files and task scheduler entry
  generate-config Generate default config file
```

### Parameters

The script uses parameter sets to ensure that parameters are only available for relevant actions.

#### Action Switches
Only one action switch can be used at a time:
- `-Install`: Install runner and register task
- `-Register`: Register task only
- `-Status`: Show task status
- `-Unregister`: Remove task
- `-Update`: Update runner binary
- `-Uninstall`: Remove runner and task
- `-GenerateConfig`: Generate config file

If no action switch is specified, help information will be displayed.

#### Installation Parameters
Available with `-Install`:
- `-TaskName`: Custom task name (default: "GiteaActionRunner")
- `-TaskDescription`: Custom task description
- `-RunnerVersion`: Specify runner version (default: "0.2.11")
- `-InstallSpace`: Installation space (default: "user")
  - `system`: System-wide installation (requires admin)
  - `user`: User space installation (no admin required)
- `-Force`: Force operation even if components exist

#### Task Management Parameters
Available with `-Register`, `-Status`, `-Unregister`:
- `-TaskName`: Custom task name (default: "GiteaActionRunner")
- `-TaskDescription`: Custom task description (only with -Register)

#### Update Parameters
Available with `-Update`:
- `-RunnerVersion`: Specify runner version (default: "0.2.11")
- `-Force`: Force update even if same version

#### Config Generation Parameters
Available with `-GenerateConfig`:
- `-ConfigFile`: Custom path for the config file
- `-RunnerFile`: Custom path for the runner file
- `-CacheDir`: Custom directory for caching
- `-WorkDir`: Custom directory for working files
- `-Labels`: Runner labels (default: "windows:host")
- `-LogLevel`: Log level (default: "info")
  - Valid values: trace, debug, info, warn, error
- `-Force`: Overwrite existing config file

### Examples

```powershell
# Installation
.\Setup.ps1 -Install -InstallSpace system -TaskName "MyRunner"

# Task Management
.\Setup.ps1 -Register -TaskName "MyRunner"
.\Setup.ps1 -Status -TaskName "MyRunner"
.\Setup.ps1 -Unregister -TaskName "MyRunner"

# Update
.\Setup.ps1 -Update -RunnerVersion "0.2.12" -Force

# Config Generation
.\Setup.ps1 -GenerateConfig -ConfigFile "config.yaml" -Labels "windows:host"

# These will fail (invalid parameter combinations):
.\Setup.ps1 -Install -ConfigFile config.yaml  # ConfigFile only valid with -GenerateConfig
.\Setup.ps1 -Status -RunnerVersion "0.2.12"  # RunnerVersion not valid with -Status
.\Setup.ps1 -Install -Register  # Can't use multiple action switches
```

### Configuration Generation

When using the `-GenerateConfig` action, additional parameters are available:

```powershell
.\Setup.ps1 -GenerateConfig [<config-parameters>]
```

#### Config Parameters
- `-ConfigFile`: Custom path for the config file
- `-RunnerFile`: Custom path for the runner file
- `-CacheDir`: Custom directory for caching
- `-WorkDir`: Custom directory for working files
- `-Labels`: Runner labels (default: "windows:host")
- `-LogLevel`: Log level (default: "info")
  - Valid values: trace, debug, info, warn, error
- `-Force`: Overwrite existing config file

#### Examples

```powershell
# Generate with default settings
.\Setup.ps1 -GenerateConfig

# Generate with custom paths
.\Setup.ps1 -GenerateConfig `
    -ConfigFile "C:\MyRunner\config.yaml" `
    -RunnerFile "C:\MyRunner\.runner" `
    -CacheDir "D:\Cache" `
    -WorkDir "D:\Work"

# Generate with custom settings
.\Setup.ps1 -GenerateConfig `
    -Labels "windows:host,docker:host" `
    -LogLevel "debug"

# Force overwrite existing config
.\Setup.ps1 -GenerateConfig -Force
```

The generated config will include detailed comments explaining each option. Default paths will be based on your installation space:
- System-wide: Uses `%ProgramData%` and `%ProgramFiles%`
- User space: Uses `%USERPROFILE%`

### Environment Configuration

Before starting the runner, you must configure the following environment variables:

### Required Variables
- `GITEA_INSTANCE_URL`: Your Gitea instance URL
- `GITEA_RUNNER_REGISTRATION_TOKEN`: Runner registration token

### Optional Variables
- `GITEA_RUNNER_NAME`: Runner name (default: computer name)
- `GITEA_RUNNER_LABELS`: Runner labels (default: windows:host)
- `GITEA_MAX_REG_ATTEMPTS`: Maximum registration attempts (default: 10)

You can set these variables in three ways:

1. Generate .env file:
```powershell
.\Setup.ps1 -GenerateDotEnv `
    -InstanceUrl "https://gitea.example.com" `
    -RunnerRegisterToken "your-token" `
    -RunnerName "MyRunner" `
    -Labels "windows:host,docker:host"
```

2. Generate config and .env together:
```powershell
.\Setup.ps1 -GenerateConfig `
    -InstanceUrl "https://gitea.example.com" `
    -RunnerRegisterToken "your-token" `
    -RunnerName "MyRunner" `
    -Labels "windows:host,docker:host"
```

3. Set environment variables manually:
```powershell
$env:GITEA_INSTANCE_URL = "https://gitea.example.com"
$env:GITEA_RUNNER_REGISTRATION_TOKEN = "your-token"
$env:GITEA_RUNNER_NAME = "MyRunner"
$env:GITEA_RUNNER_LABELS = "windows:host,docker:host"
```

### Examples

```powershell
# Show help
.\Setup.ps1
.\Setup.ps1 -Action help

# System-wide installation (requires admin)
.\Setup.ps1 -Install -InstallSpace system

# User space installation (no admin required)
.\Setup.ps1 -Install -InstallSpace user

# Generate default config
.\Setup.ps1 -GenerateConfig

# Generate config with force overwrite
.\Setup.ps1 -GenerateConfig -Force

# Install with custom task name and version
.\Setup.ps1 -TaskName "MyRunner" -RunnerVersion "0.2.12"

# Only register task scheduler
.\Setup.ps1 -Register

# Check task status (no admin required)
.\Setup.ps1 -Status

# Remove task
.\Setup.ps1 -Unregister

# Update runner
.\Setup.ps1 -Update -RunnerVersion "0.2.12"

# Uninstall runner
.\Setup.ps1 -Uninstall                           # No admin if user space and no task
.\Setup.ps1 -Uninstall -InstallSpace system      # Requires admin
```

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
  - `install`: Requires admin
  - `register`: Requires admin
  - `status`: No admin required
  - `unregister`: Requires admin
  - `update`: Requires admin when task exists and is running
  - `uninstall`: Requires admin (only when removing system-wide installation or task exists)

- User Space Installation (`-InstallSpace user`):
  - No admin privileges required for any action except:
    - When task scheduler entry exists (for uninstall)
    - When updating with task running (for update)
  - All other operations within user's home directory

### Directory Structure

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
.\Setup.ps1 -Status

# View detailed status
Get-ScheduledTask -TaskName "GiteaActionRunner" | Select-Object *

# Start the runner
Start-ScheduledTask -TaskName "GiteaActionRunner"

# Stop the runner
Stop-ScheduledTask -TaskName "GiteaActionRunner"

# Remove the task (requires admin)
.\Setup.ps1 -Unregister
```

## Logging

The script provides simple and clear logging with two levels:

### Log Levels

- `INFO`: Normal operational messages (green for success)
- `ERROR`: Error messages with optional details

### Log Format

```
[TIMESTAMP] LEVEL MESSAGE
```

Example:
```
[2025-01-14 21:59:00] INFO Starting installation...
[2025-01-14 21:59:01] ERROR Failed to create directory: Access denied
```

### Log File Locations

- Installation logs: `<script_directory>\install.log`
  - Persists between installations and uninstallations
  - Contains complete setup history

- Runner logs (based on installation space):
  - System-wide: `%ProgramData%\GiteaActRunner\logs\runner.log`
  - User space: `%USERPROFILE%\.gitea\act_runner\data\logs\runner.log`

### Log Features

- Consistent timestamp format (yyyy-MM-dd HH:mm:ss)
- Color-coded console output:
  - INFO in white (green for success)
  - ERROR in red
- Error logging with optional details
- Installation history preserved in script directory

### Viewing Logs

```powershell
# View installation logs (always in script directory)
Get-Content ".\install.log"

# View runner logs
# For system-wide installation
Get-Content "$env:ProgramData\GiteaActRunner\logs\runner.log"

# For user space installation
Get-Content "$env:USERPROFILE\.gitea\act_runner\data\logs\runner.log"

# Filter by log level
Get-Content ".\install.log" | Select-String "INFO"
Get-Content ".\install.log" | Select-String "ERROR"
```

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
   .\Setup.ps1 -Force
   
   # Check installation logs
   Get-Content ".\install.log"
   ```

2. Task Scheduler Issues:
   ```powershell
   # Check task status
   .\Setup.ps1 -Status
   
   # Recreate task (run as administrator)
   .\Setup.ps1 -Unregister
   .\Setup.ps1 -Register -Force
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