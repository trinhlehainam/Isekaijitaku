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

# Enable strict error handling
$ErrorActionPreference = 'Stop'

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
Set-ErrorLogFile -Path "$LOGS_DIR\runner.error"

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
function Register-Runner {
    $max_registration_attempts = if ($env:GITEA_MAX_REG_ATTEMPTS) { [int]$env:GITEA_MAX_REG_ATTEMPTS } else { 10 }
    Write-Log "Maximum registration attempts: $max_registration_attempts"

    Write-Log "Checking runner registration..."
    
    if (-not (Test-Path $env:RUNNER_STATE_FILE)) {
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
                    FilePath = "act_runner"
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
                    Write-Log "SUCCESS"
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
                throw
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

Register-Runner

# Start runner
Write-Log "Starting runner..."
try {
    $params = @("daemon")
    if ($env:CONFIG_FILE) {
        Write-Log "Using custom config file: $env:CONFIG_FILE"
        $params += @("--config", $env:CONFIG_FILE)
    }
    $process_params = @{
        FilePath = "act_runner"
            ArgumentList = $params
            NoNewWindow = $true
            RedirectStandardOutput = "$LOGS_DIR\runner.log"
            RedirectStandardError = "$LOGS_DIR\runner.error"
            PassThru = $true
    }
    $process = Start-Process @process_params
    Wait-Process -InputObject $process
} catch {
    Write-ErrorLog "Failed to start runner: $_"
    exit 1
} finally {
    if ($null -ne $process -and $process.HasExited -eq $false) {
        Stop-Process -InputObject $process -Force
    }
}
