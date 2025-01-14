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
- Create and configure the scheduled task

2. Configure the runner:
   - Edit `%USERPROFILE%\GiteaActionRunner\scripts\Run.ps1`
   - Set your Gitea instance URL and registration token

3. Start the runner:
```powershell
Start-ScheduledTask -TaskName "GiteaActionRunner"
```

## File Structure

```
%USERPROFILE%/
├── .cache/
│   ├── actcache/     # Cache directory for actions/cache
│   └── act/          # Work directory for job execution
└── GiteaActionRunner/
    ├── bin/
    │   └── act_runner.exe
    ├── scripts/
    │   └── Run.ps1
    ├── config.yaml   # Runner configuration
    ├── .runner       # Runner registration state
    └── logs/
        ├── install.log
        └── runner.log
```

## Task Management

The runner is installed as a scheduled task "GiteaActionRunner" and configured to:
- Start automatically on system boot
- Restart automatically on failure (up to 3 times)
- Run with SYSTEM privileges
- Start when system becomes available
- Run only when network is available

Manage the task using standard PowerShell commands:
```powershell
# Start the runner
Start-ScheduledTask -TaskName "GiteaActionRunner"

# Stop the runner
Stop-ScheduledTask -TaskName "GiteaActionRunner"

# Get status
Get-ScheduledTask -TaskName "GiteaActionRunner"
```

## Logging

Logs can be found in:
- Runner logs: `%USERPROFILE%\GiteaActionRunner\logs\runner.log`
- Installation logs: `%USERPROFILE%\GiteaActionRunner\logs\install.log`
- Windows Event Viewer under Task Scheduler logs

## Security Considerations

- The task runs with SYSTEM privileges
- Configuration files are protected with appropriate ACLs
- Registration tokens are removed from memory after successful registration
- All operations are logged for auditing purposes

## Troubleshooting

1. If the task fails to start:
   - Check the logs in `%USERPROFILE%\GiteaActionRunner\logs\runner.log`
   - Verify the Gitea instance URL and registration token
   - Ensure the runner is not already registered

2. If registration fails:
   - Verify the registration token is valid
   - Check network connectivity to the Gitea instance
   - Ensure the Gitea instance URL is correct

3. If the runner is not detected by Gitea:
   - Check if the runner is properly registered
   - Verify the runner task is running
   - Check network connectivity