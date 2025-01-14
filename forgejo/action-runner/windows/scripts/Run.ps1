# Gitea Runner Execution Script
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
    [ValidateSet('system', 'user')]
    [string]$InstallSpace = 'user',

    [Parameter(Mandatory=$false)]
    [string]$ConfigFile
)

# Import logging module
Import-Module "$PSScriptRoot\LogHelpers.psm1" -Force

# Configuration based on installation space
if ($InstallSpace -eq 'system') {
    # System-wide installation
    $PROGRAM_DIR = "$env:ProgramFiles\GiteaActRunner"
    $DATA_DIR = "$env:ProgramData\GiteaActRunner"
} else {
    # User space installation
    $PROGRAM_DIR = "$env:USERPROFILE\.gitea\act_runner\bin"
    $DATA_DIR = "$env:USERPROFILE\.gitea\act_runner\data"
}

# Derived paths
$BIN_DIR = "$PROGRAM_DIR\bin"
$LOGS_DIR = "$DATA_DIR\logs"
$DEFAULT_CONFIG = "$DATA_DIR\config.yaml"
$RUNNER_STATE = "$DATA_DIR\.runner"

# Use provided config file or default
$CONFIG_FILE = if ($ConfigFile) { $ConfigFile } else { $DEFAULT_CONFIG }

# Initialize logging
if (-not (Test-Path $LOGS_DIR)) {
    New-Item -ItemType Directory -Force -Path $LOGS_DIR | Out-Null
}
Set-LogFile -Path "$LOGS_DIR\runner.log"

# Ensure runner exists
$runnerExe = "$BIN_DIR\act_runner.exe"
if (-not (Test-Path $runnerExe)) {
    Write-ErrorLog "Runner not found at: $runnerExe"
    Write-ErrorLog "Please run Setup.ps1 first"
    exit 1
}

# Check if runner is registered
if (-not (Test-Path $RUNNER_STATE) -and (-not $InstanceUrl -or -not $RegistrationToken)) {
    Write-ErrorLog "Runner not registered and registration parameters not provided"
    Write-ErrorLog "Please provide -InstanceUrl and -RegistrationToken for first run"
    exit 1
}

# Register runner if needed
if (-not (Test-Path $RUNNER_STATE) -and $InstanceUrl -and $RegistrationToken) {
    Write-Log "Registering runner..."
    try {
        & $runnerExe register `
            --instance $InstanceUrl `
            --token $RegistrationToken `
            --name $RunnerName `
            --labels $Labels `
            --config $CONFIG_FILE
    } catch {
        Write-ErrorLog "Failed to register runner: $_"
        exit 1
    }
}

# Start runner
Write-Log "Starting runner..."
try {
    & $runnerExe daemon --config $CONFIG_FILE
} catch {
    Write-ErrorLog "Failed to start runner: $_"
    exit 1
}
