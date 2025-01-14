# Setting Up Gitea Action Runner on Windows (Host/VM Method)

This guide explains how to set up Gitea Action Runner directly on Windows using PowerShell scripts.

## Prerequisites

- Windows 10/11 Pro or Windows Server 2019/2022
- PowerShell 5.1 or later
- Administrative privileges
- A running Forgejo/Gitea instance
- Access to Forgejo/Gitea dashboard with admin privileges

## Installation Steps

1. Run the installation script as Administrator:
```powershell
.\Install.ps1
```

This script will:
- Create necessary directories
- Download and install the Gitea Runner binary
- Add the binary directory to PATH
- Install the Run script
- Create and configure the Windows Service

2. Configure the runner:
   - Edit `$HOME\GiteaActionRunner\bin\scripts\Run.ps1`
   - Set your Gitea instance URL and registration token

3. Start the service:
```powershell
Start-Service GiteaActionRunner
```

## File Structure

```
$HOME/GiteaActionRunner/
├── bin/
│   ├── act_runner.exe
│   └── scripts/
│       └── Run.ps1
├── config/
│   └── config.yaml
└── logs/
    └── runner.log
```

## Service Management

The service is installed as "GiteaActionRunner" and configured to:
- Start automatically on system boot
- Restart automatically on failure
- Run with SYSTEM privileges

Manage the service using standard Windows commands:
```powershell
# Start the service
Start-Service GiteaActionRunner

# Stop the service
Stop-Service GiteaActionRunner

# Check service status
Get-Service GiteaActionRunner
```

## Logging

Logs can be found in:
- Runner logs: `$HOME/GiteaActionRunner/logs/runner.log`
- Windows Event Viewer under Application logs

## Security Considerations

- The service runs with SYSTEM privileges
- Configuration files are protected with appropriate ACLs
- Registration tokens are removed from memory after successful registration
- All operations are logged for auditing purposes

## Troubleshooting

1. If the service fails to start:
   - Check the logs in `$HOME/GiteaActionRunner/logs/runner.log`
   - Verify the Gitea instance URL and registration token
   - Ensure the runner is not already registered

2. If registration fails:
   - Verify the registration token is valid
   - Check network connectivity to the Gitea instance
   - Ensure the Gitea instance URL is correct

3. If the runner is not detected by Gitea:
   - Check if the runner is properly registered
   - Verify the runner service is running
   - Check network connectivity