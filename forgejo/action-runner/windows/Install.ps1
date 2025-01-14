# Gitea Runner Installation Script
# This script downloads and installs the Gitea Runner binary and sets up the Windows service

# Import logging module
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$ScriptPath\scripts\LogHelpers.psm1" -Force

# Ensure we're running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-ErrorLog "This script must be run as Administrator"
    exit 1
}

# Ensure we stop on errors
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Configuration
$GITEA_RUNNER_VERSION = "0.2.11"  # Update this as needed
$INSTALL_DIR = "$env:USERPROFILE\GiteaActionRunner"
$BIN_DIR = "$INSTALL_DIR\bin"
$CONFIG_DIR = "$INSTALL_DIR\config"
$LOGS_DIR = "$INSTALL_DIR\logs"
$SCRIPTS_DIR = "$BIN_DIR\scripts"
$CONFIG_FILE = "$CONFIG_DIR\config.yaml"
$RUNNER_STATE_FILE = "$CONFIG_DIR\.runner"
$CACHE_DIR = "$env:USERPROFILE\.cache\actcache"
$WORK_DIR = "$env:USERPROFILE\.cache\act"

# Initialize logging
Set-LogFile -Path "$LOGS_DIR\install.log"

# Create necessary directories
Write-Log "Creating installation directories..."
$directories = @($INSTALL_DIR, $BIN_DIR, $CONFIG_DIR, $LOGS_DIR, $SCRIPTS_DIR, $CACHE_DIR, $WORK_DIR)
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
$downloadUrl = "https://dl.gitea.com/act_runner/$GITEA_RUNNER_VERSION/act_runner-$GITEA_RUNNER_VERSION-windows-$arch.exe"
$outputFile = "$BIN_DIR\act_runner.exe"

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
# References:
# https://gitea.com/gitea/act_runner/src/branch/main/internal/pkg/config/config.example.yaml

# Example configuration file, it's safe to copy this as the default config file without any modification.

# You don't have to copy this file to your instance,
# just run `./act_runner generate-config > config.yaml` to generate a config file.

log:
  # The level of logging, can be trace, debug, info, warn, error, fatal
  level: info

runner:
  # Where to store the registration result.
  file: $($RUNNER_STATE_FILE.Replace('\', '/'))
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
  # If it's empty, the cache data will be stored in $HOME/.cache/actcache.
  dir: "$($CACHE_DIR.Replace('\', '/'))"
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
  # If it's empty, $HOME/.cache/act/ will be used.
  workdir_parent: "$($WORK_DIR.Replace('\', '/'))"
"@ | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
Write-Log "Created config file at: $CONFIG_FILE"

# Copy Run script to scripts directory
$scriptSource = Join-Path $PSScriptRoot "scripts\Run.ps1"
$scriptDest = Join-Path $SCRIPTS_DIR "Run.ps1"
Copy-Item -Path $scriptSource -Destination $scriptDest -Force
Write-Log "Copied Run.ps1 to $scriptDest"

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

# Remove existing service if it exists
if (Get-Service $SERVICE_NAME -ErrorAction SilentlyContinue) {
    Write-Log "Removing existing service..."
    Stop-Service $SERVICE_NAME -Force
    $existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$SERVICE_NAME'"
    $existingService.Delete()
    Start-Sleep -Seconds 2
}

$SERVICE_NAME = "GiteaActionRunner"
$DISPLAY_NAME = "Gitea Action Runner"
$DESCRIPTION = "Runs Gitea Actions for CI/CD workflows"
# Create service
Write-Log "Creating Windows Service..."
try {
    $binPath = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptDest`" -ConfigFile `"$CONFIG_FILE`""
    $service = New-Service -Name $SERVICE_NAME `
        -DisplayName $DISPLAY_NAME `
        -Description $DESCRIPTION `
        -BinaryPathName $binPath `
        -StartupType Automatic
    
    # Configure service recovery options using WMI
    $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$SERVICE_NAME'"
    
    # First failure: Restart after 1 minute
    # Second failure: Restart after 1 minute
    # Third failure: Restart after 1 minute
    # Reset failure count after 1 day (86400 seconds)
    $wmiService.Change($null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null,
        "1/60000/1/60000/1/60000/86400")
    
    Write-SuccessLog "Service created successfully"
    Write-Log "NOTE: You need to configure the service with your Gitea instance URL and registration token"
    Write-Log "To configure and start the service, run:"
    Write-Log "1. Edit $scriptDest and set your Gitea instance URL and registration token"
    Write-Log "2. Start-Service $SERVICE_NAME"
    
} catch {
    Write-ErrorLog "Failed to create service: $_"
    exit 1
}

Write-SuccessLog "`nInstallation completed successfully!"
Write-Log "Binary location: $outputFile"
Write-Log "Config location: $CONFIG_FILE"
Write-Log "Script location: $scriptDest"
Write-Log "Service name: $SERVICE_NAME"
Write-Log "Cache directory: $CACHE_DIR"
Write-Log "Work directory: $WORK_DIR"
