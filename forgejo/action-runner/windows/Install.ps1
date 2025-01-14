# Gitea Runner Installation Script
# This script provides various options for installing and managing Gitea Runner

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        'install-runner',
        'register-task',
        'get-status',
        'remove-task',
        'update-runner',
        'uninstall',
        'help'
    )]
    [string]$Action = 'help',

    [Parameter(Mandatory=$false)]
    [string]$TaskName = "GiteaActionRunner",

    [Parameter(Mandatory=$false)]
    [string]$TaskDescription = "Runs Gitea Actions for CI/CD workflows",

    [Parameter(Mandatory=$false)]
    [string]$RunnerVersion = "0.2.11",

    [Parameter(Mandatory=$false)]
    [ValidateSet('system', 'user')]
    [string]$InstallSpace = 'user',

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Import logging module
Import-Module "$PSScriptRoot\scripts\LogHelpers.psm1" -Force

# Ensure we stop on errors
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Configuration based on installation space
if ($InstallSpace -eq 'system') {
    # System-wide installation (Program Files)
    $PROGRAM_DIR = "$env:ProgramFiles\GiteaActRunner"
    $DATA_DIR = "$env:ProgramData\GiteaActRunner"
} else {
    # User space installation
    $PROGRAM_DIR = "$env:USERPROFILE\.gitea\act_runner\bin"
    $DATA_DIR = "$env:USERPROFILE\.gitea\act_runner\data"
}

# Derived paths
$BIN_DIR = "$PROGRAM_DIR\bin"
$SCRIPTS_DIR = "$PROGRAM_DIR\scripts"
$LOGS_DIR = "$DATA_DIR\logs"
$CONFIG_FILE = "$DATA_DIR\config.yaml"
$RUNNER_STATE_FILE = "$DATA_DIR\.runner"
$CACHE_DIR = "$DATA_DIR\cache\actcache"
$WORK_DIR = "$DATA_DIR\work"

# Initialize logging
Set-LogFile -Path "$LOGS_DIR\install.log"

function Show-Help {
    @"
Gitea Runner Installation Script
Usage: .\Install.ps1 [-Action <action>] [-TaskName <name>] [-InstallSpace <space>] [-RunnerVersion <version>] [-Force]

Actions:
  help           Show this help message (default)
  install-runner Install the runner and register task scheduler
  register-task  Register the task in Task Scheduler
  get-status     Get task scheduler status
  remove-task    Remove the task scheduler entry
  update-runner  Update the runner binary
  uninstall      Remove runner files and task scheduler entry

Parameters:
  -Action <action>         The action to perform (default: help)
  -TaskName <name>        Task scheduler name (default: GiteaActionRunner)
  -TaskDescription <desc> Task scheduler description
  -RunnerVersion <ver>    Runner version to install (default: 0.2.11)
  -InstallSpace <space>   Installation space: 'system' or 'user' (default: user)
                         'system' requires admin rights and installs to Program Files
                         'user' installs to user's home directory
  -Force                  Force operation even if components exist

Examples:
  # Show help
  .\Install.ps1
  .\Install.ps1 -Action help

  # System-wide installation (requires admin)
  .\Install.ps1 -Action install-runner -InstallSpace system

  # User space installation (no admin required)
  .\Install.ps1 -Action install-runner -InstallSpace user

  # Register task with custom name
  .\Install.ps1 -Action register-task -TaskName "MyRunner"

  # Check status
  .\Install.ps1 -Action get-status

  # Update runner
  .\Install.ps1 -Action update-runner -RunnerVersion "0.2.12"

  # Uninstall runner
  .\Install.ps1 -Action uninstall

Note: System-wide installation (-InstallSpace system) requires administrative privileges
"@ | Write-Host
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    return $principal.IsInRole($adminRole)
}

function Test-InstallPermissions {
    if ($InstallSpace -eq 'system' -and -not (Test-AdminPrivileges)) {
        Write-ErrorLog "System-wide installation requires administrative privileges. Please run as Administrator or use -InstallSpace user"
        return $false
    }
    return $true
}

function Install-Runner {
    Write-Log "Installing Gitea Runner..."
    
    # Create directories
    $directories = @(
        $PROGRAM_DIR,
        $BIN_DIR,
        $SCRIPTS_DIR,
        $DATA_DIR,
        $LOGS_DIR,
        $CACHE_DIR,
        $WORK_DIR
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            Write-Log "Creating directory: $dir"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    $osArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $arch = switch -Wildcard ($osArch) { 
        '64-bit*' { 'amd64' } 
        'ARM64*' { 'arm64' } 
        default { 
            Write-ErrorLog "Unsupported architecture: $osArch"
            exit 1
        } 
    }

    # Download and extract runner
    $runnerUrl = "https://dl.gitea.com/act_runner/$RunnerVersion/act_runner-$RunnerVersion-windows-$arch.exe"
    $exeFile = "$BIN_DIR\act_runner.exe"
    
    try {
        Write-Log "Downloading runner from: $runnerUrl"
        Invoke-WebRequest -Uri $runnerUrl -OutFile $exeFile
    } catch {
        Write-ErrorLog "Failed to download runner: $_"
        exit 1
    }

    # Copy scripts
    Write-Log "Copying scripts..."
    Copy-Item "$PSScriptRoot\scripts\*" $SCRIPTS_DIR -Force
    
    # Create default config if it doesn't exist
    # Reference: https://gitea.com/gitea/act_runner/src/branch/main/internal/pkg/config/config.example.yaml
    if (-not (Test-Path $CONFIG_FILE) -or $Force) {
        Write-Log "Creating default config..."
        @"
# Example configuration file, it's safe to copy this as the default config file without any modification.

# You don't have to copy this file to your instance,
# just run `./act_runner generate-config > config.yaml` to generate a config file.

log:
  # The level of logging, can be trace, debug, info, warn, error, fatal
  level: info

runner:
  # Where to store the registration result.
  file: $RUNNER_STATE_FILE
  # Execute how many tasks concurrently at the same time.
  capacity: 1
  # Extra environment variables to run jobs.
  envs:
  # Extra environment variables to run jobs from a file.
  # It will be ignored if it's empty or the file doesn't exist.
  env_file: .env
  # The timeout for a job to be finished.
  # Please note that the Gitea instance also has a timeout (3h by default) for the job.
  # So the job could be stopped by the Gitea instance if it's timeout is shorter than this.
  timeout: 3h
  # The timeout for the runner to wait for running jobs to finish when shutting down.
  # Any running jobs that haven't finished after this timeout will be cancelled.
  shutdown_timeout: 0s
  # Whether skip verifying the TLS certificate of the Gitea instance.
  insecure: false
  # The timeout for fetching the job from the Gitea instance.
  fetch_timeout: 5s
  # The interval for fetching the job from the Gitea instance.
  fetch_interval: 2s
  # The labels of a runner are used to determine which jobs the runner can run, and how to run them.
  # Like: "macos-arm64:host" or "ubuntu-latest:docker://gitea/runner-images:ubuntu-latest"
  # Find more images provided by Gitea at https://gitea.com/gitea/runner-images .
  # If it's empty when registering, it will ask for inputting labels.
  # If it's empty when execute `daemon`, will use labels in `.runner` file.
  labels:
    - "windows:host"

cache:
  # Enable cache server to use actions/cache.
  enabled: true
  # The directory to store the cache data.
  dir: $CACHE_DIR
  # The host of the cache server.
  # It's not for the address to listen, but the address to connect from job containers.
  # So 0.0.0.0 is a bad choice, leave it empty to detect automatically.
  host: ""
  # The port of the cache server.
  # 0 means to use a random available port.
  port: 0
  # The external cache server URL. Valid only when enable is true.
  # If it's specified, act_runner will use this URL as the ACTIONS_CACHE_URL rather than start a server by itself.
  # The URL should generally end with "/".
  external_server: ""

container:
  # Specifies the network to which the container will connect.
  # Could be host, bridge or the name of a custom network.
  # If it's empty, act_runner will create a network automatically.
  network: ""
  # Whether to use privileged mode or not when launching task containers (privileged mode is required for Docker-in-Docker).
  privileged: false
  # And other options to be used when the container is started (eg, --add-host=my.gitea.url:host-gateway).
  options:
  # The parent directory of a job's working directory.
  # NOTE: There is no need to add the first '/' of the path as act_runner will add it automatically. 
  # If the path starts with '/', the '/' will be trimmed.
  # For example, if the parent directory is /path/to/my/dir, workdir_parent should be path/to/my/dir
  # If it's empty, /workspace will be used.
  workdir_parent:
  # Volumes (including bind mounts) can be mounted to containers. Glob syntax is supported, see https://github.com/gobwas/glob
  # You can specify multiple volumes. If the sequence is empty, no volumes can be mounted.
  # For example, if you only allow containers to mount the `data` volume and all the json files in `/src`, you should change the config to:
  # valid_volumes:
  #   - data
  #   - /src/*.json
  # If you want to allow any volume, please use the following configuration:
  # valid_volumes:
  #   - '**'
  valid_volumes: []
  # overrides the docker client host with the specified one.
  # If it's empty, act_runner will find an available docker host automatically.
  # If it's "-", act_runner will find an available docker host automatically, but the docker host won't be mounted to the job containers and service containers.
  # If it's not empty or "-", the specified docker host will be used. An error will be returned if it doesn't work.
  docker_host: ""
  # Pull docker image(s) even if already present
  force_pull: true
  # Rebuild docker image(s) even if already present
  force_rebuild: false

host:
  # The parent directory of a job's working directory.
  workdir_parent: $WORK_DIR
"@ | Out-File $CONFIG_FILE -Encoding utf8 -Force
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
            -WorkingDirectory $PROGRAM_DIR

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

function Uninstall-Runner {
    Write-Log "Uninstalling Gitea Runner..."

    # Check if task exists
    $taskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    # If task exists and we need admin rights
    if ($taskExists) {
        if (-not (Test-AdminPrivileges)) {
            Write-ErrorLog "Removing task scheduler entry requires administrative privileges. Please run as Administrator."
            exit 1
        }
        
        Write-Log "Stopping task: $TaskName"
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Write-Log "Removing task: $TaskName"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # Remove directories based on install space
    if ($InstallSpace -eq 'system' -and -not (Test-AdminPrivileges)) {
        Write-ErrorLog "Removing system-wide installation requires administrative privileges. Please run as Administrator."
        exit 1
    }

    # Remove directories
    $directories = @($PROGRAM_DIR, $DATA_DIR)
    foreach ($dir in $directories) {
        if (Test-Path $dir) {
            Write-Log "Removing directory: $dir"
            try {
                Remove-Item -Path $dir -Recurse -Force
            } catch {
                Write-ErrorLog "Failed to remove directory $dir`: $_"
                exit 1
            }
        }
    }

    # Clear log file before final message since the log directory will be gone
    Set-LogFile -Path $null
    Write-SuccessLog "Uninstallation completed successfully!"
}

# Main script execution
switch ($Action.ToLower()) {
    'help' {
        Show-Help
    }
    'install-runner' {
        if (-not (Test-InstallPermissions)) {
            exit 1
        }
        Install-Runner
        if (Test-AdminPrivileges -or $InstallSpace -eq 'user') {
            Register-RunnerTask
            Write-Log "`nTo configure and start the runner:"
            Write-Log "1. Edit $SCRIPTS_DIR\Run.ps1 and set your Gitea instance URL and registration token"
            Write-Log "2. Start-ScheduledTask -TaskName $TaskName"
        }
    }
    'register-task' {
        if (-not (Test-InstallPermissions)) {
            exit 1
        }
        if (-not (Test-Path $SCRIPTS_DIR\Run.ps1)) {
            Write-ErrorLog "Runner not installed. Please run with -Action install-runner first."
            exit 1
        }
        Register-RunnerTask
    }
    'get-status' {
        Get-RunnerTaskStatus
    }
    'remove-task' {
        if (-not (Test-InstallPermissions)) {
            exit 1
        }
        Remove-RunnerTask
    }
    'update-runner' {
        if (-not (Test-InstallPermissions)) {
            exit 1
        }
        Update-Runner
    }
    'uninstall' {
        Uninstall-Runner
    }
    default {
        Write-ErrorLog "Unknown action: $Action"
        Show-Help
        exit 1
    }
}
