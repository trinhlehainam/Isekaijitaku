[CmdletBinding(DefaultParameterSetName='Help')]
param(
    [Parameter(Mandatory=$true, ParameterSetName='Install')]
    [switch]$Install,

    [Parameter(Mandatory=$true, ParameterSetName='Register')]
    [switch]$Register,

    [Parameter(Mandatory=$true, ParameterSetName='Status')]
    [switch]$Status,

    [Parameter(Mandatory=$true, ParameterSetName='Unregister')]
    [switch]$Unregister,

    [Parameter(Mandatory=$true, ParameterSetName='Update')]
    [switch]$Update,

    [Parameter(Mandatory=$true, ParameterSetName='Uninstall')]
    [switch]$Uninstall,

    [Parameter(Mandatory=$true, ParameterSetName='GenerateConfig')]
    [switch]$GenerateConfig,

    [Parameter(Mandatory=$false, ParameterSetName='Install', Position=1)]
    [Parameter(Mandatory=$false, ParameterSetName='Register', Position=1)]
    [Parameter(Mandatory=$false, ParameterSetName='Status', Position=1)]
    [Parameter(Mandatory=$false, ParameterSetName='Unregister', Position=1)]
    [Parameter(Mandatory=$false, ParameterSetName='Update', Position=1)]
    [Parameter(Mandatory=$false, ParameterSetName='Uninstall', Position=1)]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig', Position=1)]
    [switch]$Help,

    # Common parameters
    [Parameter(Mandatory=$false)]
    [switch]$Force=$false,

    # Installation parameters
    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='Uninstall')]
    [ValidateSet('system', 'user')]
    [string]$InstallSpace = 'user',

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='Register')]
    [string]$TaskName = "GiteaActionRunner",

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='Register')]
    [string]$TaskDescription = "Gitea Action Runner Service",

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='Update')]
    [string]$RunnerVersion = "0.2.11",

    # Config generation parameters
    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig')]
    [string]$CacheDir,

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig')]
    [string]$WorkDir,

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig')]
    [string]$Labels = "windows:host",

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig')]
    [ValidateSet('trace', 'debug', 'info', 'warn', 'error')]
    [string]$LogLevel = "info",

    # Environment variables
    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig')]
    [string]$InstanceUrl,

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig')]
    [string]$RunnerRegisterToken,

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig')]
    [string]$RunnerName = $env:COMPUTERNAME,

    # Task registration flag
    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [switch]$RegisterTask
)

# Configuration based on installation space
if ($InstallSpace -eq 'system') {
    # System-wide installation
    $PROGRAM_DIR = "$env:ProgramFiles\GiteaActRunner"
    $DATA_DIR = "$env:ProgramData\GiteaActRunner"
} else {
    # User space installation
    $PROGRAM_DIR = "$env:USERPROFILE\.gitea\act_runner"
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

# Import modules
Import-Module "$PSScriptRoot\scripts\helpers\LogHelpers.psm1" -Force
Import-Module "$PSScriptRoot\scripts\helpers\DotEnvHelper.psm1" -Force

# Initialize logging in script directory for persistence
Set-LogFile -Path "$PSScriptRoot\install.log"

# Ensure we stop on errors
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Show-Help {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Action
    )

    switch ($Action) {
        'Install' {
            $helpText = @"
Install Action Help
------------------
Installs the Gitea Runner and optionally registers it as a scheduled task.

Usage: 
    .\Setup.ps1 -Install [parameters]

Parameters:
    -InstallSpace       Installation space [system|user] (default: user)
    -TaskName          Custom task name (default: GiteaActionRunner)
    -TaskDescription   Custom task description
    -RunnerVersion     Runner version (default: 0.2.11)
    -RegisterTask      Register as scheduled task after installation
    -Force            Force operation even if components exist

Configuration Parameters:
    -InstanceUrl       Gitea instance URL
    -RunnerRegisterToken Registration token
    -RunnerName        Runner name (default: computer name)
    -Labels           Runner labels (default: windows:host)
    -LogLevel         Log level [trace|debug|info|warn|error]
    -CacheDir         Custom directory for caching
    -WorkDir          Custom directory for working files

Examples:
    # Basic installation in user space
    .\Setup.ps1 -Install

    # Full installation with task registration and configuration
    .\Setup.ps1 -Install -InstallSpace system `
        -InstanceUrl "https://gitea.example.com" `
        -RunnerRegisterToken "token123" `
        -RegisterTask `
        -TaskName "MyRunner" `
        -Labels "windows:host,docker"
"@
        }
        'Register' {
            $helpText = @"
Register Action Help
-------------------
Registers the runner as a scheduled task.

Usage:
    .\Setup.ps1 -Register [parameters]

Parameters:
    -TaskName         Custom task name (default: GiteaActionRunner)
    -TaskDescription  Custom task description
    -Force           Force operation even if task exists

Examples:
    # Register with default settings
    .\Setup.ps1 -Register

    # Register with custom name and description
    .\Setup.ps1 -Register -TaskName "MyRunner" -TaskDescription "Custom Runner"
"@
        }
        'Status' {
            $helpText = @"
Status Action Help
-----------------
Shows the status of the runner task.

Usage:
    .\Setup.ps1 -Status

No additional parameters required.
"@
        }
        'Update' {
            $helpText = @"
Update Action Help
-----------------
Updates the runner binary to a specified version.

Usage:
    .\Setup.ps1 -Update [parameters]

Parameters:
    -RunnerVersion   Runner version (default: 0.2.11)
    -Force          Force update even if version matches

Examples:
    # Update to specific version
    .\Setup.ps1 -Update -RunnerVersion "0.2.12"
"@
        }
        'Uninstall' {
            $helpText = @"
Uninstall Action Help
--------------------
Removes the runner and optionally its task.

Usage:
    .\Setup.ps1 -Uninstall [parameters]

Parameters:
    -Force          Force removal even if components are in use

Examples:
    # Uninstall runner
    .\Setup.ps1 -Uninstall
"@
        }
        'GenerateConfig' {
            $helpText = @"
Generate Config Action Help
-------------------------
Generates configuration and environment files.

Usage:
    .\Setup.ps1 -GenerateConfig [parameters]

Parameters:
    -InstanceUrl          Gitea instance URL
    -RunnerRegisterToken  Registration token
    -RunnerName          Runner name (default: computer name)
    -Labels             Runner labels (default: windows:host)
    -LogLevel           Log level [trace|debug|info|warn|error]
    -CacheDir           Custom directory for caching
    -WorkDir            Custom directory for working files
    -Force             Force overwrite of existing files

Examples:
    # Generate with minimal settings
    .\Setup.ps1 -GenerateConfig -InstanceUrl "https://gitea.example.com" -RunnerRegisterToken "token123"

    # Generate with all options
    .\Setup.ps1 -GenerateConfig `
        -InstanceUrl "https://gitea.example.com" `
        -RunnerRegisterToken "token123" `
        -RunnerName "MyRunner" `
        -Labels "windows:host,docker" `
        -LogLevel "debug" `
        -CacheDir "C:\Cache" `
        -WorkDir "C:\Work"
"@
        }
        default {
            $helpText = @"
Gitea Runner Installation Script
Usage: Setup.ps1 [action] [parameters]

ACTIONS:
    -Install         Install runner and optionally register task
    -Register        Register task only
    -Status          Show task status
    -Unregister      Remove task
    -Update          Update runner binary
    -Uninstall       Remove runner and task
    -GenerateConfig  Generate config and env files
    -Help            Show help

For action-specific help, use:
    .\Setup.ps1 -Help -[Action]

Example:
    .\Setup.ps1 -Help -Install
"@
        }
    }
    Write-Host $helpText
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

function New-RunnerConfig {
    param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigFile,

        [Parameter(Mandatory=$false)]
        [string]$RunnerFile,

        [Parameter(Mandatory=$false)]
        [string]$CacheDir,

        [Parameter(Mandatory=$false)]
        [string]$WorkDir,

        [Parameter(Mandatory=$false)]
        [string]$InstanceUrl="",

        [Parameter(Mandatory=$false)]
        [string]$RunnerRegisterToken="",

        [Parameter(Mandatory=$false)]
        [string]$Labels = "windows:host",

        [Parameter(Mandatory=$false)]
        [ValidateSet('trace', 'debug', 'info', 'warn', 'error')]
        [string]$LogLevel = 'info',

        [Parameter(Mandatory=$false)]
        [string]$RunnerName = $env:COMPUTERNAME
    )

    Write-Log "Generating runner configuration..."

    # Create parent directories if they don't exist
    $configDir = Split-Path -Parent $ConfigFile
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    }

    # Generate .env file
    New-DotEnvFile -InstanceUrl $InstanceUrl -RunnerRegisterToken $RunnerRegisterToken -RunnerName $RunnerName -Labels $Labels -ConfigFile $ConfigFile

    # Reference: https://gitea.com/gitea/act_runner/src/branch/main/internal/pkg/config/config.example.yaml
    $configContent = @"
# Example configuration file, it's safe to copy this as the default config file without any modification.

# You don't have to copy this file to your instance,
# just run `./act_runner generate-config > config.yaml` to generate a config file.

log:
  # The level of logging, can be trace, debug, info, warn, error, fatal
  level: $LogLevel

runner:
  # Where to store the registration result.
  file: $RunnerFile
  # Execute how many tasks concurrently at the same time.
  capacity: 1
  # Extra environment variables to run jobs.
  envs:
    A_TEST_ENV_NAME_1: a_test_env_value_1
    A_TEST_ENV_NAME_2: a_test_env_value_2
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
    - $Labels

cache:
  # Enable cache server to use actions/cache.
  enabled: true
  # The directory to store the cache data.
  dir: $CacheDir
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
  workdir_parent: $WorkDir
"@

    try {
        Write-Log "Writing config to: $ConfigFile"
        Set-Content -Path $ConfigFile -Value $configContent -Force
        Write-SuccessLog "Config file generated successfully at: $ConfigFile"
    } catch {
        Write-ErrorLog "Failed to write config file: $_"
        exit 1
    }
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
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
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
    
    if ((Test-Path $exeFile) -and (-not $Force)) {
        Write-Log "Runner already exists at: $exeFile"
        return
    }
    
    try {
        Write-Log "Downloading runner from: $runnerUrl"
        Invoke-WebRequest -Uri $runnerUrl -OutFile $exeFile
    } catch {
        Write-ErrorLog "Failed to download runner: $_"
        exit 1
    }

    # Copy scripts
    Write-Log "Copying scripts to: $SCRIPTS_DIR"
    Copy-Item "$PSScriptRoot\scripts\*" $SCRIPTS_DIR -Force
    
    # Add runner directory to PATH
    Write-Log "Updating PATH: $BIN_DIR"
    $newPath = ('{0};{1}' -f $BIN_DIR, $env:PATH)
    if ($InstallSpace -eq 'system') {
        [Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine)
    }
    if ($InstallSpace -eq 'user') {
        [Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::User)
    }

    Write-SuccessLog "Installation completed successfully!"
}

function New-FirewallRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RuleName,
        [Parameter(Mandatory=$true)]
        [string]$exeFile
    )
    # Create firewall rule for the task
    try {
        # Remove existing rule if any
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

        # Create new rule
        $params = @{
            DisplayName = $ruleName
            Direction   = "Inbound"
            Program     = $exeFile
            Action      = "Allow"
            Profile     = @("Private", "Public")
            Description = "Allow Gitea Action Runner to have network access"
            Enabled     = "True"
        }
            
        New-NetFirewallRule @params -ErrorAction Stop | Out-Null
        Write-SuccessLog "Network access rule created for $exeFile"
        return $true
    }
    catch {
        Write-ErrorLog "Failed to create network access rule: $_"
        return $false
    }
}

function Register-RunnerTask {
    param(
        [Parameter(Mandatory = $false)]
        [string]$TaskName = "GiteaActionRunner",

        [Parameter(Mandatory = $false)]
        [string]$TaskDescription = "Gitea Action Runner Service"
    )

    Write-Log "Registering task: $TaskName"

    # Load environment variables if .env exists
    $envFile = Join-Path $DATA_DIR ".env"
    Import-DotEnv -Path $envFile

    # Define required environment variables
    $requiredVars = @(
        @{Name = 'GITEA_INSTANCE_URL'; Description = 'Gitea instance URL'},
        @{Name = 'GITEA_RUNNER_REGISTRATION_TOKEN'; Description = 'Runner registration token'}
    )

    # Validate required environment variables
    if (-not (Test-RequiredEnvironmentVariables -RequiredVars $requiredVars)) {
        throw "Cannot register runner: Missing required environment variables. Please set them in the .env file or provide them as parameters."
    }

    if (-not (Test-InstallPermissions)) {
        exit 1
    }

    # Check if task exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask -and -not $Force) {
        Write-ErrorLog "Task already exists: $TaskName. Use -Force to overwrite"
        exit 1
    }

    # Remove existing task if force
    if ($existingTask -and $Force) {
        Write-Log "Removing existing task: $TaskName"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    try {
        # Create firewall rule for the task
        $ruleName = "GiteaActionRunner"
        $exeFile = "$BIN_DIR\act_runner.exe"
        if (-not (New-FirewallRule -RuleName $ruleName -exeFile $exeFile)) {
            exit 1
        }

        # Create task action
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SCRIPTS_DIR\Run.ps1`"" `
            -WorkingDirectory $DATA_DIR

        # Create task trigger (at system startup)
        $trigger = New-ScheduledTaskTrigger -AtStartup

        # Configure task settings
        $settings = New-ScheduledTaskSettingsSet `
            -ExecutionTimeLimit (New-TimeSpan -Days 365) `
            -RestartCount 3 `
            -RestartInterval (New-TimeSpan -Minutes 1) `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable

        # Configure task principal (run with highest privileges)
        $principal = New-ScheduledTaskPrincipal `
            -UserId "SYSTEM" `
            -LogonType ServiceAccount `
            -RunLevel Highest

        # Register the task
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Description $TaskDescription `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Force

        Write-SuccessLog "Task registered successfully: $TaskName"
    }
    catch {
        Write-ErrorLog "Failed to register task: $_"
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

function Unregister-RunnerTask {
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
        if (-not (Test-AdminPrivileges)) {
            Write-ErrorLog "Runner task is running. Please stop the task and try again."
            exit 1
        }
        Write-Log "Stopping runner task..."
        Stop-ScheduledTask -TaskName $TaskName
    }

    # Force reinstall the runner
    Install-Runner -Force
    
    # Restart the task if it exists
    if ($task) {
        if (-not (Test-AdminPrivileges)) {
            Write-ErrorLog "Restarting runner task requires administrative privileges. Please run as Administrator."
            exit 1
        }
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

    Write-SuccessLog "Uninstallation completed successfully!"
}

function New-DotEnvFile {
    param(
        [Parameter(Mandatory=$false)]
        [string]$InstanceUrl,

        [Parameter(Mandatory=$false)]
        [string]$RunnerRegisterToken,

        [Parameter(Mandatory=$false)]
        [string]$RunnerName,

        [Parameter(Mandatory=$false)]
        [string]$Labels,

        [Parameter(Mandatory=$false)]
        [string]$ConfigFile
    )

    Write-Log "Generating .env file..."

    $envPath = Join-Path $DATA_DIR ".env"

    # Create parent directory if it doesn't exist
    $envDir = Split-Path -Parent $envPath
    if (-not (Test-Path $envDir)) {
        New-Item -ItemType Directory -Force -Path $envDir | Out-Null
    }

    $envContent = @"
# Gitea Runner Configuration
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Configuration paths
CONFIG_FILE=$ConfigFile

# Runner registration details
GITEA_INSTANCE_URL=$InstanceUrl
GITEA_RUNNER_REGISTRATION_TOKEN=$RunnerRegisterToken
GITEA_RUNNER_NAME=$RunnerName
GITEA_RUNNER_LABELS=$Labels

# Optional configuration
GITEA_MAX_REG_ATTEMPTS=10
"@

    Write-Log "Writing environment file to: $envPath"
    $envContent | Out-File -FilePath $envPath -Encoding utf8 -Force
    Write-SuccessLog "Environment file generated successfully at: $envPath"
}

# Main script execution
if ($PSCmdlet.ParameterSetName -eq 'Help' -or $Help) {
    $action = $PSBoundParameters.Keys | Where-Object { $_ -ne 'Help' } | Select-Object -First 1
    Show-Help -Action $action
    return
}

switch ($PSCmdlet.ParameterSetName) {
    'Install' {
        Install-Runner

        $configParams = @{}
        if ($PSBoundParameters.ContainsKey('InstanceUrl')) { $configParams['InstanceUrl'] = $InstanceUrl }
        if ($PSBoundParameters.ContainsKey('RunnerRegisterToken')) { $configParams['RunnerRegisterToken'] = $RunnerRegisterToken }
        if ($PSBoundParameters.ContainsKey('ConfigFile')) { $configParams['ConfigFile'] = $ConfigFile } else { $configParams['ConfigFile'] = $CONFIG_FILE }
        if ($PSBoundParameters.ContainsKey('RunnerFile')) { $configParams['RunnerFile'] = $RunnerFile } else { $configParams['RunnerFile'] = $RUNNER_STATE_FILE }
        if ($PSBoundParameters.ContainsKey('CacheDir')) { $configParams['CacheDir'] = $CacheDir } else { $configParams['CacheDir'] = $CACHE_DIR }
        if ($PSBoundParameters.ContainsKey('WorkDir')) { $configParams['WorkDir'] = $WorkDir } else { $configParams['WorkDir'] = $WORK_DIR }

        if (-not (Test-Path $CONFIG_FILE) -or ($Force)) {
            New-RunnerConfig @configParams
        }

        if ($RegisterTask) {
            if (-not (Test-InstallPermissions)) {
                exit 1
            }

            $taskParams = @{
                TaskName = $TaskName
                TaskDescription = $TaskDescription
            }
            if ($Force) { $taskParams['Force'] = $true }
            
            Register-RunnerTask @taskParams
        }
    }
    'Register' {
        if (-not (Test-InstallPermissions)) {
            exit 1
        }
        Register-RunnerTask
    }
    'Status' {
        Get-RunnerTaskStatus
    }
    'Unregister' {
        if (-not (Test-InstallPermissions)) {
            exit 1
        }
        Unregister-RunnerTask
    }
    'Update' {
        Update-Runner
    }
    'Uninstall' {
        Uninstall-Runner
    }
    'GenerateConfig' {
        $configParams = @{}
        if ($PSBoundParameters.ContainsKey('InstanceUrl')) { $configParams['InstanceUrl'] = $InstanceUrl }
        if ($PSBoundParameters.ContainsKey('RunnerRegisterToken')) { $configParams['RunnerRegisterToken'] = $RunnerRegisterToken }
        if ($PSBoundParameters.ContainsKey('ConfigFile')) { $configParams['ConfigFile'] = $ConfigFile }
        if ($PSBoundParameters.ContainsKey('RunnerFile')) { $configParams['RunnerFile'] = $RunnerFile }
        if ($PSBoundParameters.ContainsKey('CacheDir')) { $configParams['CacheDir'] = $CacheDir }
        if ($PSBoundParameters.ContainsKey('WorkDir')) { $configParams['WorkDir'] = $WorkDir }
        if ($PSBoundParameters.ContainsKey('Labels')) { $configParams['Labels'] = $Labels }
        if ($PSBoundParameters.ContainsKey('LogLevel')) { $configParams['LogLevel'] = $LogLevel }
        if ($PSBoundParameters.ContainsKey('RunnerName')) { $configParams['RunnerName'] = $RunnerName }
        
        New-RunnerConfig @configParams
    }
}