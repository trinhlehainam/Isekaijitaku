# Gitea Runner Setup Guide for Windows

## Overview

This guide explains how to set up the Gitea Runner on Windows using Windows Services. The runner can be installed either system-wide (requires admin rights) or in user space.

## Prerequisites

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Administrator rights (for system installation)
- Network access to Gitea instance

## Installation

### Quick Start

1. Basic installation (user space):
```powershell
.\Setup.ps1 -Install
```

2. Full installation with service registration:
```powershell
.\Setup.ps1 -Install `
    -InstallSpace system `
    -InstanceUrl "https://gitea.example.com" `
    -RunnerRegisterToken "token123" `
    -RunnerName "MyRunner" `
    -Labels "windows,docker" `
    -RegisterService `
    -ServiceName "MyGiteaRunner"
```

### Installation Options

- `-Install`: Install the runner
- `-InstallSpace`: Installation space [system|user] (default: user)
- `-RunnerVersion`: Runner version (default: 0.2.11)
- `-Force`: Force overwrite existing files/service

- `-InstanceUrl`: Gitea instance URL
- `-RunnerRegisterToken`: Registration token
- `-RunnerName`: Custom runner name
- `-Labels`: Runner labels (default: windows:host)
- `-LogLevel`: Log level [trace|debug|info|warn|error]
- `-CacheDir`: Custom cache directory
- `-WorkDir`: Custom work directory

- `-RegisterService`: Register as Windows Service
- `-ServiceName`: Custom service name (default: GiteaActionRunner)
- `-ServiceDescription`: Custom service description

## Service Management

### Service Registration

Register runner as a Windows Service:
```powershell
.\Setup.ps1 -Register `
    -ServiceName "MyGiteaRunner" `
    -InstanceUrl "https://gitea.example.com" `
    -RunnerRegisterToken "token123"
```

### Service Status

Check service status:
```powershell
.\Setup.ps1 -Status
```

### Service Removal

Remove service:
```powershell
.\Setup.ps1 -Unregister
```

### Service Properties

The service is configured with:
- System account execution
- Highest privileges
- Automatic startup
- Network access
- Restart on failure (3 attempts)
- No execution time limit

### Service Recovery

Automatic recovery settings:
- First failure: Restart after 1 minute
- Second failure: Restart after 1 minute
- Third failure: Restart after 1 minute
- Reset count: After 24 hours

## Directory Structure

### System Installation
- Program: `%ProgramFiles%\GiteaActRunner`
- Data: `%ProgramData%\GiteaActRunner`

### User Installation
- Program: `%USERPROFILE%\.gitea\act_runner`
- Data: `%USERPROFILE%\.gitea\act_runner\data`

### Common Directories
- Binary: `[Program]\bin`
- Scripts: `[Program]\scripts`
- Logs: `[Data]\logs`
- Cache: `[Data]\cache\actcache`
- Work: `[Data]\work`

## Configuration Files

- Config: `[Data]\config.yaml`
- Environment: `[Data]\.env`
- Runner State: `[Data]\.runner`

## Network Configuration

### Firewall Rules

The setup creates:
- Service-specific rule (GiteaRunner_[ServiceName])
- Inbound TCP connections
- Private and public profiles
- Limited to runner executable

### Network Access

The service runs with:
- Full network access
- System account privileges
- Outbound connections to Gitea
- Inbound connections for actions

## Logging

Find logs in:
- Runner log: `[Data]\logs\runner.log`
- Error log: `[Data]\logs\runner.error`
- Windows Event logs

## Troubleshooting

### Common Issues

1. Service won't start:
   - Check service credentials
   - Verify file permissions
   - Check network access
   - Review event logs

2. Registration fails:
   - Verify token
   - Check network
   - Review runner logs
   - Confirm URL access

3. Network issues:
   - Check firewall rules
   - Verify proxy settings
   - Test Gitea access
   - Review network logs

### Best Practices

1. Security:
   - Use system account
   - Restrict file access
   - Monitor service status
   - Regular updates

2. Maintenance:
   - Monitor logs
   - Update runner
   - Check disk space
   - Verify network

3. Performance:
   - Clean work directory
   - Monitor resources
   - Check service health
   - Regular restarts

## Updates

Update runner:
```powershell
.\Setup.ps1 -Update
```

## Uninstallation

Remove runner and service:
```powershell
.\Setup.ps1 -Uninstall
```

## Environment Variables

Required:
- `GITEA_INSTANCE_URL`
- `GITEA_RUNNER_REGISTRATION_TOKEN`

Optional:
- `GITEA_RUNNER_NAME`
- `GITEA_RUNNER_LABELS`
- `CONFIG_FILE`

## Support

For issues:
1. Check logs in `[Data]\logs`
2. Review Windows Event Viewer
3. Check network access
4. Verify service status

## References

- [Gitea Runner Documentation](https://docs.gitea.com/usage/actions/act-runner)
- [Windows Services](https://docs.microsoft.com/en-us/windows/win32/services/services)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)