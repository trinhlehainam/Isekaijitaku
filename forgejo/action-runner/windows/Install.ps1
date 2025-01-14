# Gitea Runner Installation Script
# This script provides various options for installing and managing Gitea Runner

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        'install-runner',
        'register-task',
        'get-status',
        'remove-task',
        'update-runner'
    )]
    [string]$Action = 'install-runner',

    [Parameter(Mandatory=$false)]
    [string]$TaskName = "GiteaActionRunner",

    [Parameter(Mandatory=$false)]
    [string]$TaskDescription = "Runs Gitea Actions for CI/CD workflows",

    [Parameter(Mandatory=$false)]
    [string]$RunnerVersion = "0.2.11",

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Import logging module
Import-Module "$PSScriptRoot\scripts\LogHelpers.psm1" -Force

# Ensure we stop on errors
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Configuration
$INSTALL_DIR = "$env:USERPROFILE\GiteaActionRunner"
$BIN_DIR = "$INSTALL_DIR\bin"
$SCRIPTS_DIR = "$INSTALL_DIR\scripts"
$LOGS_DIR = "$INSTALL_DIR\logs"
$CONFIG_FILE = "$INSTALL_DIR\config.yaml"
$RUNNER_STATE_FILE = "$INSTALL_DIR\.runner"
$CACHE_DIR = "$env:USERPROFILE\.cache\actcache"
$WORK_DIR = "$env:USERPROFILE\.cache\act"

# Initialize logging
Set-LogFile -Path "$LOGS_DIR\install.log"

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    
    if (-not $principal.IsInRole($adminRole)) {
        Write-ErrorLog "This action requires administrative privileges. Please run as Administrator."
        return $false
    }
    return $true
}

function Install-Runner {
    Write-Log "Installing Gitea Runner..."
    
    # Create necessary directories
    Write-Log "Creating installation directories..."
    $directories = @($INSTALL_DIR, $BIN_DIR, $SCRIPTS_DIR, $LOGS_DIR, $CACHE_DIR, $WORK_DIR)
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
    }

    # Detect CPU architecture
    $osArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $arch = switch -Wildcard ($osArch) {
        '64-bit*' { 'amd64' }
        'ARM64*' { 'arm64' }
        default { throw "Unsupported architecture: $osArch" }
    }
    Write-Log "Detected architecture: $arch"

    # Download Gitea Runner
    $downloadUrl = "https://dl.gitea.com/act_runner/$RunnerVersion/act_runner-$RunnerVersion-windows-$arch.exe"
    $outputFile = "$BIN_DIR\act_runner.exe"

    if ((Test-Path $outputFile) -and -not $Force) {
        Write-Log "Runner already installed. Use -Force to reinstall."
        return
    }

    Write-Log "Downloading Gitea Runner from: $downloadUrl"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile
        if (-not (Test-Path $outputFile)) {
            throw "Failed to download runner executable"
        }
    } catch {
        Write-ErrorLog "Failed to download Gitea Runner: $_"
        exit 1
    }

    # Verify the executable
    try {
        $version = & $outputFile --version
        Write-SuccessLog "Successfully installed Gitea Runner: $version"
    } catch {
        Write-ErrorLog "Failed to verify runner executable: $_"
        exit 1
    }

    # Generate default config.yaml
    Write-Log "Generating default configuration..."
    @"
log:
  level: info

runner:
  file: $($RUNNER_STATE_FILE.Replace('\', '/'))
  capacity: 1
  envs:
  env_file: .env
  timeout: 3h
  shutdown_timeout: 0s
  insecure: false
  fetch_timeout: 5s
  fetch_interval: 2s
  labels:
    - "windows:host"

cache:
  enabled: true
  dir: "$($CACHE_DIR.Replace('\', '/'))"
  host: ""
  port: 0
  external_server: ""

container:
  network: ""
  privileged: false
  options:
  workdir_parent:
  valid_volumes: []
  docker_host: ""
  force_pull: true
  force_rebuild: false

host:
  workdir_parent: "$($WORK_DIR.Replace('\', '/'))"
"@ | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
    Write-Log "Created config file at: $CONFIG_FILE"

    # Copy Run script to scripts directory
    Copy-Item -Path "$PSScriptRoot\scripts\Run.ps1" -Destination "$SCRIPTS_DIR\Run.ps1" -Force
    Write-Log "Copied Run.ps1 to $SCRIPTS_DIR"

    # Add to PATH if not already present
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $currentPath.Contains($BIN_DIR)) {
        [Environment]::SetEnvironmentVariable(
            "Path",
            "$currentPath;$BIN_DIR",
            "User"
        )
        Write-Log "Added runner directory to PATH"
    }

    Write-SuccessLog "Installation completed successfully!"
}

function Register-RunnerTask {
    Write-Log "Setting up Task Scheduler..."
    
    # Remove existing task if it exists
    Write-Log "Checking for existing scheduled task..."
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        if (-not $Force) {
            Write-Log "Task already exists. Use -Force to replace it."
            return
        }
        Write-Log "Removing existing task..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    try {
        # Create action to run the script
        $action = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SCRIPTS_DIR\Run.ps1`" -ConfigFile `"$CONFIG_FILE`"" `
            -WorkingDirectory $INSTALL_DIR

        # Create trigger for automatic start
        $trigger = New-ScheduledTaskTrigger -AtStartup

        # Create principal (run with highest privileges)
        $principal = New-ScheduledTaskPrincipal `
            -UserId "SYSTEM" `
            -LogonType ServiceAccount `
            -RunLevel Highest

        # Create settings
        $settings = New-ScheduledTaskSettingsSet `
            -MultipleInstances IgnoreNew `
            -RestartCount 3 `
            -RestartInterval (New-TimeSpan -Minutes 1) `
            -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable

        # Register the task
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Description $TaskDescription `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings

        Write-SuccessLog "Scheduled task created successfully"
        Write-Log "Task name: $TaskName"
    } catch {
        Write-ErrorLog "Failed to create scheduled task: $_"
        exit 1
    }
}

function Get-RunnerTaskStatus {
    Write-Log "Checking Task Scheduler status..."
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Log "Task '$TaskName' not found"
        return
    }

    Write-Log "Task Details:"
    Write-Log "  Name: $($task.TaskName)"
    Write-Log "  State: $($task.State)"
    Write-Log "  Last Run Time: $($task.LastRunTime)"
    Write-Log "  Last Result: $($task.LastTaskResult)"
    Write-Log "  Next Run Time: $($task.NextRunTime)"
    
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
    Write-Log "  Last Run Time: $($taskInfo.LastRunTime)"
    Write-Log "  Last Run Result: $($taskInfo.LastTaskResult)"
    Write-Log "  Number of Missed Runs: $($taskInfo.NumberOfMissedRuns)"
}

function Remove-RunnerTask {
    Write-Log "Removing Task Scheduler entry..."
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Log "Task '$TaskName' not found"
        return
    }

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-SuccessLog "Task '$TaskName' removed successfully"
    } catch {
        Write-ErrorLog "Failed to remove task: $_"
        exit 1
    }
}

function Update-Runner {
    Write-Log "Updating Gitea Runner..."
    
    # Stop the task if it exists and is running
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq 'Running') {
        Write-Log "Stopping runner task..."
        Stop-ScheduledTask -TaskName $TaskName
    }

    # Force reinstall the runner
    Install-Runner -Force
    
    # Restart the task if it exists
    if ($task) {
        Write-Log "Restarting runner task..."
        Start-ScheduledTask -TaskName $TaskName
    }
}

# Main script execution
switch ($Action.ToLower()) {
    'install-runner' {
        Install-Runner
        if (Test-AdminPrivileges) {
            Register-RunnerTask
            Write-Log "`nTo configure and start the runner:"
            Write-Log "1. Edit $SCRIPTS_DIR\Run.ps1 and set your Gitea instance URL and registration token"
            Write-Log "2. Start-ScheduledTask -TaskName $TaskName"
        } else {
            Write-Log "`nRunner installed but task scheduler not configured (requires admin privileges)"
            Write-Log "To configure the task scheduler, run again as administrator with:"
            Write-Log ".\Install.ps1 -Action register-task"
        }
    }
    'register-task' {
        if (-not (Test-AdminPrivileges)) {
            exit 1
        }
        if (-not (Test-Path $SCRIPTS_DIR\Run.ps1)) {
            Write-ErrorLog "Runner not installed. Please run with -Action 'install-runner' first."
            exit 1
        }
        Register-RunnerTask
    }
    'get-status' {
        Get-RunnerTaskStatus
    }
    'remove-task' {
        if (-not (Test-AdminPrivileges)) {
            exit 1
        }
        Remove-RunnerTask
    }
    'update-runner' {
        Update-Runner
    }
}
