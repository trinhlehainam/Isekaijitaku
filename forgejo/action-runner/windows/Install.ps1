# Gitea Runner Installation Script
# This script downloads and installs the Gitea Runner binary and sets up the Windows service

# Ensure we're running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
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
$SERVICE_NAME = "GiteaActionRunner"
$DISPLAY_NAME = "Gitea Action Runner"
$DESCRIPTION = "Runs Gitea Actions for CI/CD workflows"

# Create necessary directories
Write-Host "Creating installation directories..."
$directories = @($INSTALL_DIR, $BIN_DIR, $CONFIG_DIR, $LOGS_DIR, $SCRIPTS_DIR)
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
Write-Host "Detected architecture: $arch"

# Download Gitea Runner
$downloadUrl = "https://dl.gitea.com/act_runner/$GITEA_RUNNER_VERSION/act_runner-$GITEA_RUNNER_VERSION-windows-$arch.exe"
$outputFile = "$BIN_DIR\act_runner.exe"

Write-Host "Downloading Gitea Runner from: $downloadUrl"
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile
    if (-not (Test-Path $outputFile)) {
        throw "Failed to download runner executable"
    }
} catch {
    Write-Error "Failed to download Gitea Runner: $_"
    exit 1
}

# Verify the executable
try {
    $version = & $outputFile --version
    Write-Host "Successfully installed Gitea Runner: $version"
} catch {
    Write-Error "Failed to verify runner executable: $_"
    exit 1
}

# Copy Run script to scripts directory
$scriptSource = Join-Path $PSScriptRoot "Run.ps1"
$scriptDest = Join-Path $SCRIPTS_DIR "Run.ps1"
Copy-Item -Path $scriptSource -Destination $scriptDest -Force
Write-Host "Copied Run.ps1 to $scriptDest"

# Add to PATH if not already present
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $currentPath.Contains($BIN_DIR)) {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$currentPath;$BIN_DIR",
        "User"
    )
    Write-Host "Added runner directory to PATH"
}

# Remove existing service if it exists
if (Get-Service $SERVICE_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing service..."
    Stop-Service $SERVICE_NAME -Force
    $existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$SERVICE_NAME'"
    $existingService.Delete()
    Start-Sleep -Seconds 2
}

# Create service
Write-Host "Creating Windows Service..."
try {
    $binPath = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptDest`""
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
    
    Write-Host "Service created successfully"
    Write-Host "NOTE: You need to configure the service with your Gitea instance URL and registration token"
    Write-Host "To configure and start the service, run:"
    Write-Host "1. Edit $scriptDest and set your Gitea instance URL and registration token"
    Write-Host "2. Start-Service $SERVICE_NAME"
    
} catch {
    Write-Error "Failed to create service: $_"
    exit 1
}

Write-Host "`nInstallation completed successfully!"
Write-Host "Binary location: $outputFile"
Write-Host "Script location: $scriptDest"
Write-Host "Service name: $SERVICE_NAME"
