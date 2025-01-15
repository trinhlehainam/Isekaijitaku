# Enable strict error handling
$ErrorActionPreference = 'Stop'

# Import modules
Import-Module "$PSScriptRoot\helpers\LogHelpers.psm1" -Force
Import-Module "$PSScriptRoot\helpers\DotEnvHelper.psm1" -Force

# Constants and paths
$PROGRAM_DIR = Split-Path -Parent $PSScriptRoot
$DATA_DIR = if ($env:GITEA_DATA_DIR) { $env:GITEA_DATA_DIR } else {
    if (Test-Path "$env:ProgramData\GiteaRunner") {
        "$env:ProgramData\GiteaRunner"
    } else {
        "$env:USERPROFILE\.gitea\runner"
    }
}

# Set up directories
$BIN_DIR = Join-Path $PROGRAM_DIR "bin"
$LOGS_DIR = Join-Path $DATA_DIR "logs"
$CONFIG_FILE = Join-Path $DATA_DIR "config.yaml"
$RUNNER_STATE_FILE = Join-Path $DATA_DIR ".runner"

# Create directories if they don't exist
if (-not (Test-Path $LOGS_DIR)) {
    New-Item -ItemType Directory -Force -Path $LOGS_DIR | Out-Null
}

Set-LogFile -Path "$LOGS_DIR\runner.log"
Set-ErrorLogFile -Path "$LOGS_DIR\runner.error"

# Load environment variables
$envFile = Join-Path $DATA_DIR ".env"
Import-DotEnv -EnvFile $envFile

# Define required environment variables
$requiredVars = @(
    @{Name = 'GITEA_INSTANCE_URL'; Description = 'Gitea instance URL'},
    @{Name = 'GITEA_RUNNER_REGISTRATION_TOKEN'; Description = 'Runner registration token'}
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

# Register runner
function Register-Runner {
    $max_registration_attempts = if ($env:GITEA_MAX_REG_ATTEMPTS) { [int]$env:GITEA_MAX_REG_ATTEMPTS } else { 10 }
    Write-Log "Maximum registration attempts: $max_registration_attempts"
    
    Write-Log "Checking runner registration..."
    
    if (-not (Test-Path $RUNNER_STATE_FILE)) {
        Write-Log "Runner not registered, starting registration..."
        
        $params = @(
            "register",
            "--instance", $env:GITEA_INSTANCE_URL,
            "--token", $env:GITEA_RUNNER_REGISTRATION_TOKEN,
            "--name", $env:GITEA_RUNNER_NAME,
            "--labels", $env:GITEA_RUNNER_LABELS
        )

        $attempt = 1
        $registered = $false

        while (-not $registered -and $attempt -le $max_registration_attempts) {
            Write-Log "Registration attempt $attempt of $max_registration_attempts"
            
            try {
                & $runnerExe $params
                $registered = $true
                Write-SuccessLog "Runner registered successfully!"
            }
            catch {
                if ($attempt -lt $max_registration_attempts) {
                    Write-Log "Registration failed, retrying in 5 seconds..."
                    Start-Sleep -Seconds 5
                }
                else {
                    Write-ErrorLog "Failed to register runner after $max_registration_attempts attempts"
                    throw
                }
            }
            $attempt++
        }
    }
    else {
        Write-Log "Runner already registered"
    }
}

# Validate environment before proceeding
Test-RequiredEnvironmentVariables -RequiredVars $requiredVars -ThrowOnError

Register-Runner

# Start runner
Write-Log "Starting Gitea Act Runner..."
try {
    $params = @("daemon")
    if ($env:CONFIG_FILE) {
        $params += @("--config", $env:CONFIG_FILE)
    }
    & $runnerExe $params
}
catch {
    Write-ErrorLog "Failed to start runner: $_"
    exit 1
}
