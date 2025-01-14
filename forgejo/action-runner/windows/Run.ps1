# Gitea Runner Script
# This script handles both registration and running of the Gitea Runner

param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$RegistrationToken,
    
    [Parameter(Mandatory=$false)]
    [string]$RunnerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$Labels = "windows,vm",

    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "$env:USERPROFILE\GiteaActionRunner\config\config.yaml"
)

# Ensure we stop on errors
$ErrorActionPreference = 'Stop'

# Configuration
$INSTALL_DIR = "$env:USERPROFILE\GiteaActionRunner"
$BIN_DIR = "$INSTALL_DIR\bin"
$CONFIG_DIR = "$INSTALL_DIR\config"
$LOGS_DIR = "$INSTALL_DIR\logs"
$LOG_FILE = "$LOGS_DIR\runner.log"
$RUNNER_EXE = "$BIN_DIR\act_runner.exe"
$STATE_FILE = "$CONFIG_DIR\.runner"

# Function to write logs with timestamp
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $LOG_FILE -Value $logMessage
}

function Write-Error-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errorMessage = "[$timestamp] ERROR: $Message"
    Write-Host $errorMessage -ForegroundColor Red
    Add-Content -Path $LOG_FILE -Value $errorMessage
}

# Create necessary directories
$directories = @($INSTALL_DIR, $BIN_DIR, $CONFIG_DIR, $LOGS_DIR)
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

# Verify installation
if (-not (Test-Path $RUNNER_EXE)) {
    Write-Error-Log "Gitea Runner not found at $RUNNER_EXE. Please run Install-Runner.ps1 first."
    exit 1
}

# Register the runner if not already registered
if (-not (Test-Path $STATE_FILE)) {
    Write-Log "Runner not registered, starting registration..."
    
    try {
        # Initialize runner configuration
        Write-Log "Generating initial configuration..."
        & $RUNNER_EXE generate-config --config $ConfigFile
        
        # Register runner
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
            Write-Error-Log "Registration failed with exit code: $($process.ExitCode)"
            exit 1
        }
        
        Write-Log "Registration successful!"
        
        # Secure the config file
        $acl = Get-Acl $ConfigFile
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "$env:USERDOMAIN\$env:USERNAME",
            "FullControl",
            "Allow"
        )
        $acl.AddAccessRule($rule)
        Set-Acl $ConfigFile $acl
        Write-Log "Secured configuration file"
        
    } catch {
        Write-Error-Log "Failed to register runner: $_"
        exit 1
    }
} else {
    Write-Log "Runner already registered"
}

# Start the runner daemon
Write-Log "Starting runner daemon..."
try {
    & $RUNNER_EXE daemon --config $ConfigFile
} catch {
    Write-Error-Log "Failed to start runner daemon: $_"
    exit 1
}
