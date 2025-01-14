# Gitea Runner Script
# This script handles both registration and running of the Gitea Runner

param(
    [Parameter(Mandatory=$false)]
    [string]$InstanceUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$RegistrationToken,
    
    [Parameter(Mandatory=$false)]
    [string]$RunnerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$Labels = "windows:host",

    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "$env:USERPROFILE\GiteaActionRunner\config.yaml"
)

# Import logging module
Import-Module "$PSScriptRoot\scripts\LogHelpers.psm1" -Force

# Ensure we stop on errors
$ErrorActionPreference = 'Stop'

# Configuration
$INSTALL_DIR = "$env:USERPROFILE\GiteaActionRunner"
$BIN_DIR = "$INSTALL_DIR\bin"
$LOGS_DIR = "$INSTALL_DIR\logs"
$LOG_FILE = "$LOGS_DIR\runner.log"
$RUNNER_EXE = "$BIN_DIR\act_runner.exe"

# Initialize logging
Set-LogFile -Path $LOG_FILE

# Create necessary directories
$directories = @($INSTALL_DIR, $BIN_DIR, $LOGS_DIR)
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

# Verify installation
if (-not (Test-Path $RUNNER_EXE)) {
    Write-ErrorLog "Gitea Runner not found at $RUNNER_EXE. Please run Install.ps1 first."
    exit 1
}

# Verify config file
if (-not (Test-Path $ConfigFile)) {
    Write-ErrorLog "Config file not found at $ConfigFile"
    exit 1
}

# Get runner state file path from config
$configContent = Get-Content $ConfigFile -Raw
if ($configContent -match "file:\s*(.+)") {
    $runnerStateFile = $matches[1].Trim()
    Write-Log "Using runner state file: $runnerStateFile"
} else {
    Write-ErrorLog "Could not find runner state file path in config"
    exit 1
}

# Register the runner if not already registered
if (-not (Test-Path $runnerStateFile)) {
    Write-Log "Runner not registered, starting registration..."
    
    # Verify registration parameters
    if (-not $InstanceUrl) {
        Write-ErrorLog "InstanceUrl parameter is required for registration"
        Write-Log "Usage: Run.ps1 -InstanceUrl <url> -RegistrationToken <token> [-RunnerName <name>] [-Labels <labels>]"
        exit 1
    }
    if (-not $RegistrationToken) {
        Write-ErrorLog "RegistrationToken parameter is required for registration"
        Write-Log "Usage: Run.ps1 -InstanceUrl <url> -RegistrationToken <token> [-RunnerName <name>] [-Labels <labels>]"
        exit 1
    }
    
    try {
        Write-Log "Registering runner with Gitea instance at $InstanceUrl"
        Write-Log "Runner name: $RunnerName"
        Write-Log "Labels: $Labels"
        
        $registerArgs = @(
            "register",
            "--instance", $InstanceUrl,
            "--token", $RegistrationToken,
            "--name", $RunnerName,
            "--labels", $Labels,
            "--config", $ConfigFile,
            "--no-interactive"
        )
        
        $process = Start-Process -FilePath $RUNNER_EXE -ArgumentList $registerArgs -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-ErrorLog "Registration failed with exit code: $($process.ExitCode)"
            exit 1
        }
        
        Write-SuccessLog "Registration successful!"
        
        # Clear sensitive data from memory
        $RegistrationToken = $null
        [System.GC]::Collect()
        
    } catch {
        Write-ErrorLog "Failed to register runner: $_"
        exit 1
    }
} else {
    Write-Log "Runner already registered"
}

# Start the runner daemon
Write-Log "Starting runner daemon..."
try {
    # Verify working directory exists
    $configContent -match "workdir_parent:\s*(.+)"
    $workDir = $matches[1].Trim().Trim('"')
    if (-not (Test-Path $workDir)) {
        Write-WarningLog "Work directory does not exist: $workDir"
        Write-Log "Creating work directory..."
        New-Item -ItemType Directory -Force -Path $workDir | Out-Null
    }

    # Start the daemon
    & $RUNNER_EXE daemon --config $ConfigFile
} catch {
    Write-ErrorLog "Failed to start runner daemon: $_"
    exit 1
}
