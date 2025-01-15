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

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='Register')]
    [Parameter(Mandatory=$false, ParameterSetName='Status')]
    [Parameter(Mandatory=$false, ParameterSetName='Unregister')]
    [Parameter(Mandatory=$false, ParameterSetName='Update')]
    [Parameter(Mandatory=$false, ParameterSetName='Uninstall')]
    [Parameter(Mandatory=$false, ParameterSetName='GenerateConfig')]
    [switch]$Help,

    # Common parameters
    [Parameter(Mandatory=$false)]
    [switch]$Force=$false,

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='Register')]
    [string]$ServiceName = "GiteaActionRunner",

    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [Parameter(Mandatory=$false, ParameterSetName='Register')]
    [string]$ServiceDescription = "Gitea Action Runner Service",

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

    # Service registration flag
    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [switch]$RegisterService
)

$ErrorActionPreference = 'Stop'

# Import modules
Import-Module "$PSScriptRoot\scripts\helpers\LogHelpers.psm1" -Force
Import-Module "$PSScriptRoot\scripts\helpers\DotEnvHelper.psm1" -Force
# Initialize logging in script directory for persistence
Set-LogFile -Path "$PSScriptRoot\install.log"

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    return $principal.IsInRole($adminRole)
}

$HasAdminRights = (Test-AdminPrivileges)
if ($HasAdminRights) {
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
Installs the Gitea Runner and optionally registers it as a Windows Service.

Usage: 
    .\Setup.ps1 -Install [parameters]

Parameters:
    -ServiceName       Custom service name (default: GiteaActionRunner)
    -ServiceDescription Custom service description
    -RunnerVersion     Runner version (default: 0.2.11)
    -RegisterService   Register as Windows Service after installation
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

    # Full installation with service registration and configuration
    .\Setup.ps1 -Install `
        -InstanceUrl "https://gitea.example.com" `
        -RunnerRegisterToken "token123" `
        -RegisterService `
        -ServiceName "MyRunner" `
        -Labels "windows:host,docker"
"@
        }
        'Register' {
            $helpText = @"
Register Action Help
-------------------
Registers the runner as a Windows Service.

Usage:
    .\Setup.ps1 -Register [parameters]

Parameters:
    -ServiceName       Custom service name (default: GiteaActionRunner)
    -ServiceDescription Custom service description
    -Force           Force operation even if service exists

Examples:
    # Register with default settings
    .\Setup.ps1 -Register

    # Register with custom name and description
    .\Setup.ps1 -Register -ServiceName "MyRunner" -ServiceDescription "Custom Runner"
"@
        }
        'Status' {
            $helpText = @"
Status Action Help
-----------------
Shows the status of the runner service.

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
Removes the runner and optionally its service.

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
    -Install         Install runner and optionally register service
    -Register        Register service only
    -Status          Show service status
    -Unregister      Remove service
    -Update          Update runner binary
    -Uninstall       Remove runner and service
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


function Test-InstallPermissions {
    if (-not (Test-AdminPrivileges)) {
        Write-ErrorLog "Installation requires administrative privileges. Please run as Administrator or use -Force"
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
    if ($HasAdminRights) {
        [Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine)
    }
    else {
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

function Get-RunnerService {
    param(
        [string]$ServiceName = "GiteaActionRunner"
    )
    
    return Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'"
}

function Register-Runner {
    # Load environment variables
    $envFile = Join-Path $DATA_DIR ".env"
    Import-DotEnv -Path $envFile

    # Define required environment variables
    $requiredVars = @(
        @{Name = 'GITEA_INSTANCE_URL'; Description = 'Gitea instance URL' },
        @{Name = 'GITEA_RUNNER_REGISTRATION_TOKEN'; Description = 'Runner registration token' }
    )

    # Use provided config file or default
    $CONFIG_FILE = if ($env:CONFIG_FILE) { $env:CONFIG_FILE } else { $CONFIG_FILE }

    # Ensure runner exists
    $runnerExe = "$BIN_DIR\act_runner.exe"
    if (-not (Test-Path $runnerExe)) {
        Write-ErrorLog "Gitea Act Runner executable not found at: $runnerExe"
        Write-ErrorLog "Please run Setup.ps1 first"
        exit 1
    }
    Test-RequiredEnvironmentVariables -RequiredVars $requiredVars -ThrowOnError

    $max_registration_attempts = if ($env:GITEA_MAX_REG_ATTEMPTS) { [int]$env:GITEA_MAX_REG_ATTEMPTS } else { 10 }
    Write-Log "Maximum registration attempts: $max_registration_attempts"

    Write-Log "Checking runner registration..."
    
    if ($Force) { 
        Write-Log "Forcing registration..."
        Remove-Item $RUNNER_STATE_FILE -ErrorAction SilentlyContinue | Out-Null
    }
    
    if (-not (Test-Path $RUNNER_STATE_FILE)) {
        Write-Log "Runner not registered, starting registration..."
        
        $params = @(
            "register",
            "--instance", $env:GITEA_INSTANCE_URL,
            "--token", $env:GITEA_RUNNER_REGISTRATION_TOKEN,
            "--name", $env:GITEA_RUNNER_NAME,
            "--labels", $env:GITEA_RUNNER_LABELS,
            "--no-interactive"
        )

        # Add optional parameters if specified
        if ($env:CONFIG_FILE) {
            Write-Log "Using custom config file: $env:CONFIG_FILE"
            $params += @("--config", $env:CONFIG_FILE)
        }

        $attempt = 1
        $success = $false

        $temp_stdout = New-TemporaryFile
        $temp_stderr = New-TemporaryFile
        
        try {
            while (-not $success -and $attempt -le $max_registration_attempts) {
                Write-Log "Registration attempt $attempt of $max_registration_attempts..."
                
                $process_params = @{
                    FilePath = $runnerExe
                    ArgumentList = $params
                    NoNewWindow = $true
                    Wait = $true
                    RedirectStandardOutput = $temp_stdout.FullName
                    RedirectStandardError = $temp_stderr.FullName
                    PassThru = $true
                }
                
                $process = Start-Process @process_params
                
                # Get combined output
                $stdout = Get-Content -Path $temp_stdout.FullName -Raw
                $stderr = Get-Content -Path $temp_stderr.FullName -Raw
                $output = "$stdout`n$stderr"
                
                # Clear files for next attempt
                Clear-Content -Path $temp_stdout.FullName
                Clear-Content -Path $temp_stderr.FullName
                
                if ($process.ExitCode -eq 0 -and $output -match "Runner registered successfully") {
                    Write-Log "Registration successful"
                    $success = $true
                }
                else {
                    Write-Log "Registration output: $output"
                    Write-Log "Waiting to retry..."
                    Start-Sleep -Seconds 5
                    $attempt++
                }
            }

            if (-not $success) {
                Write-ErrorLog "Runner registration failed after $max_registration_attempts attempts"
                exit 1
            }

            # Remove registration token variables after successful registration
            Write-Log "Removing registration token from environment"
            Remove-Item Env:\GITEA_RUNNER_REGISTRATION_TOKEN -ErrorAction SilentlyContinue
            Remove-Item Env:\GITEA_RUNNER_REGISTRATION_TOKEN_FILE -ErrorAction SilentlyContinue
        }
        finally {
            # Clean up temp files
            Remove-Item -Path $temp_stdout.FullName -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $temp_stderr.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Log "Runner already registered"
    }
}
function Register-RunnerService {
    param(
        [string]$ServiceName = "GiteaActionRunner",
        [string]$DisplayName = "Gitea Action Runner Service",
        [string]$Description = "Runs Gitea Actions for CI/CD pipelines"
    )

    Write-Log "Registering service: $ServiceName"
    
    if (-not (Test-InstallPermissions)) {
        exit 1
    }

    Register-Runner

    # Check if service exists
    $existingService = Get-RunnerService -ServiceName $ServiceName
    if ($existingService -and -not $Force) {
        Write-ErrorLog "Service already exists: $ServiceName. Use -Force to overwrite"
        exit 1
    }

    # Remove existing service if force
    if ($existingService -and $Force) {
        Write-Log "Removing existing service: $ServiceName"
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2 # Wait for service removal
    }

    try {
        # Create the service
        $cmdPath = "`"$BIN_DIR\act_runner.exe`" daemon"
        if ($env:CONFIG_FILE) {
            Write-Log "Using custom config file: $env:CONFIG_FILE"
            $cmdPath = "`"$BIN_DIR\act_runner.exe`" daemon --config `"$env:CONFIG_FILE`""
        }
        $params = @{
            Name = $ServiceName
            BinaryPathName = $cmdPath
            DisplayName = $DisplayName
            Description = $Description
            StartupType = 'Automatic'
        }
        
        New-Service @params
        
        # Configure recovery options through registry
        # $recoveryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
        # Set-ItemProperty -Path $recoveryPath -Name "FailureActions" -Value ([byte[]](
        #     0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x03,0x00,0x00,0x00,
        #     0x60,0xEA,0x00,0x00,0x01,0x00,0x00,0x00,0x60,0xEA,0x00,0x00,0x01,0x00,0x00,0x00,
        #     0x60,0xEA,0x00,0x00,0x01,0x00,0x00,0x00
        # ))

        # Add network access permissions
        # Create firewall rule for the service
        $ruleName = "GiteaRunner_$ServiceName"
        $exeFile = "$BIN_DIR\act_runner.exe"
        if (-not (New-FirewallRule -RuleName $ruleName -exeFile $exeFile)) {
            exit 1
        }

        # Start the service
        Start-Service -Name $ServiceName
        
        # Get service status using CIM
        $serviceStatus = Get-RunnerService -ServiceName $ServiceName
        Write-SuccessLog "Service registered and started successfully: $ServiceName (State: $($serviceStatus.State))"
    }
    catch {
        Write-ErrorLog "Failed to register service: $_"
        exit 1
    }
}

function Get-RunnerServiceStatus {
    param(
        [string]$ServiceName = "GiteaActionRunner"
    )
    
    try {
        $service = Get-RunnerService -ServiceName $ServiceName
        if (-not $service) {
            Write-ErrorLog "Service not found: $ServiceName"
            return $false
        }
        
        Write-Log "Service status:"
        Write-Log "Name: $($service.Name)"
        Write-Log "DisplayName: $($service.DisplayName)"
        Write-Log "State: $($service.State)"
        Write-Log "StartMode: $($service.StartMode)"
        Write-Log "PathName: $($service.PathName)"
        Write-Log "ProcessId: $($service.ProcessId)"
        Write-Log "StartName: $($service.StartName)"
        Write-Log "Description: $($service.Description)"

        return @{
            Name = $service.Name
            DisplayName = $service.DisplayName
            State = $service.State
            StartMode = $service.StartMode
            PathName = $service.PathName
            ProcessId = $service.ProcessId
            StartName = $service.StartName
            Description = $service.Description
        }
    }
    catch {
        Write-ErrorLog "Failed to get service status: $_"
        return $false
    }
}

function Unregister-RunnerService {
    param(
        [string]$ServiceName = "GiteaActionRunner"
    )

    Write-Log "Removing service..."
    
    $service = Get-RunnerService -ServiceName $ServiceName
    if (-not $service) {
        Write-Log "Service '$ServiceName' not found"
        return
    }

    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue
        Write-SuccessLog "Service '$ServiceName' removed successfully"
    } catch {
        Write-ErrorLog "Failed to remove service: $_"
        exit 1
    }
}

function Update-Runner {
    Write-Log "Updating Gitea Runner..."
    
    # Stop the service if it exists and is running
    $service = Get-RunnerService -ServiceName $ServiceName
    if ($service -and $service.State -eq 'Running') {
        if (-not (Test-AdminPrivileges)) {
            Write-ErrorLog "Runner service is running. Please stop the service and try again."
            exit 1
        }
        Write-Log "Stopping runner service..."
        Stop-Service -Name $ServiceName
    }

    # Force reinstall the runner
    Install-Runner -Force
    
    # Restart the service if it exists
    if ($service) {
        if (-not (Test-AdminPrivileges)) {
            Write-ErrorLog "Restarting runner service requires administrative privileges. Please run as Administrator."
            exit 1
        }
        Write-Log "Restarting runner service..."
        Start-Service -Name $ServiceName
    }
}

function Uninstall-Runner {
    Write-Log "Uninstalling Gitea Runner..."

    # Check if service exists
    $serviceExists = Get-RunnerService -ServiceName $ServiceName
    
    # If service exists and we need admin rights
    if ($serviceExists) {
        if ($HasAdminRights) {
            Write-Log "Stopping service: $ServiceName"
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Write-Log "Removing service: $ServiceName"
            Unregister-RunnerService -ServiceName $ServiceName
        }
        else {
            Write-WarningLog "Removing service requires administrative privileges. Please run as Administrator."
        }
    }

    # Remove directories
    $directories = @($PROGRAM_DIR, $DATA_DIR)
    $success = $true
    foreach ($dir in $directories) {
        if (Test-Path $dir) {
            Write-Log "Removing directory: $dir"
            try {
                Remove-Item -Path $dir -Recurse -Force
            } catch {
                Write-ErrorLog "Failed to remove directory $dir`: $_"
                $success = $false
            }
        }
    }

    if ($success) {
        Write-SuccessLog "Uninstallation completed successfully!"
    }
    else {
        Write-ErrorLog "Uninstallation failed."
    }
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

        if ($RegisterService) {
            if (-not $HasAdminRights) {
                exit 1
            }

            $serviceParams = @{
                ServiceName = $ServiceName
                DisplayName = $ServiceDescription
            }
            if ($Force) { $serviceParams['Force'] = $true }
            
            Register-RunnerService @serviceParams
        }
    }
    'Register' {
        if (-not $HasAdminRights) {
            exit 1
        }
        Register-RunnerService
    }
    'Status' {
        Get-RunnerServiceStatus
    }
    'Unregister' {
        if (-not $HasAdminRights) {
            exit 1
        }
        Unregister-RunnerService
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