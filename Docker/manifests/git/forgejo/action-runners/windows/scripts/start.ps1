# References:
# - Gitea Runner: https://gitea.com/gitea/act_runner
# - Run Script: https://gitea.com/gitea/act_runner/raw/branch/main/scripts/run.sh

# Enable strict error handling
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = if ($Level -eq 'ERROR') { 'Red' } else { 'White' }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-Error-And-Throw {
    param(
        [string]$Message
    )
    Write-Log $Message -Level ERROR
    throw $Message
}

function Test-Environment {
    Write-Log "Checking environment variables..."
    
    # Check GITEA_INSTANCE_URL
    if (-not $env:GITEA_INSTANCE_URL) {
        Write-Error-And-Throw "GITEA_INSTANCE_URL environment variable is required"
    }

    # Check token from environment or file
    if (-not $env:GITEA_RUNNER_REGISTRATION_TOKEN -and $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE) {
        if (Test-Path $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE) {
            try {
                $env:GITEA_RUNNER_REGISTRATION_TOKEN = Get-Content $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE -Raw -ErrorAction Stop
                Write-Log "Successfully read token from file"
            }
            catch {
                Write-Error-And-Throw "Failed to read token from file: $_"
            }
        }
        else {
            Write-Error-And-Throw "Token file not found"
        }
    }

    if (-not $env:GITEA_RUNNER_REGISTRATION_TOKEN) {
        Write-Error-And-Throw "GITEA_RUNNER_REGISTRATION_TOKEN environment variable or GITEA_RUNNER_REGISTRATION_TOKEN_FILE must be provided"
    }

    # Set default values for optional parameters
    if (-not $env:GITEA_RUNNER_NAME) {
        $env:GITEA_RUNNER_NAME = [System.Net.Dns]::GetHostName()
        Write-Log "Using hostname as runner name: $env:GITEA_RUNNER_NAME"
    }

    if (-not $env:GITEA_RUNNER_LABELS) {
        $env:GITEA_RUNNER_LABELS = "windows:host"
        Write-Log "Using default labels: $env:GITEA_RUNNER_LABELS"
    }

    # Set default state file path
    if (-not $env:RUNNER_STATE_FILE) {
        $env:RUNNER_STATE_FILE = ".runner"
    }

    # Validate config file if specified
    if ($env:CONFIG_FILE -and -not (Test-Path $env:CONFIG_FILE)) {
        Write-Error-And-Throw "Specified CONFIG_FILE does not exist: $env:CONFIG_FILE"
    }
}

# Verify act_runner exists before proceeding
$act_runner_cmd = Join-Path $env:ProgramData "Gitea-Act-Runner\bin\act_runner.exe"
if (-not (Test-Path $act_runner_cmd)) {
    Write-Error-And-Throw "Gitea Runner not found at $act_runner_cmd"
}

function Register-Runner {
    $max_registration_attempts = if ($env:GITEA_MAX_REG_ATTEMPTS) { [int]$env:GITEA_MAX_REG_ATTEMPTS } else { 10 }
    Write-Log "Maximum registration attempts: $max_registration_attempts"

    Write-Log "Checking runner registration..."
    
    if (-not (Test-Path $env:RUNNER_STATE_FILE)) {
        Write-Log "Runner not registered, starting registration..."
        
        $params = @(
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

        # The point of this loop is to make it simple, when running both act_runner and gitea in docker,
        # for the act_runner to wait a moment for gitea to become available before erroring out.  Within
        # the context of a single docker-compose, something similar could be done via healthchecks, but
        # this is more flexible.
        while (-not $success -and $attempt -le $max_registration_attempts) {
            Write-Log "Registration attempt $attempt of $max_registration_attempts..."
            
            $output = & $act_runner_cmd register $params | Out-String
                
                if ($output -match "Runner registered successfully") {
                    Write-Log "SUCCESS"
                    $success = $true
                }
                else {
                Write-Log "Waiting to retry..."
                Start-Sleep -Seconds 5
                $attempt++
            }
        }

        if (-not $success) {
            Write-Error-And-Throw "Runner registration failed after $max_registration_attempts attempts"
        }

        # Remove registration token variables after successful registration
        Write-Log "Removing registration token from environment"
        Remove-Item Env:\GITEA_RUNNER_REGISTRATION_TOKEN -ErrorAction SilentlyContinue
        Remove-Item Env:\GITEA_RUNNER_REGISTRATION_TOKEN_FILE -ErrorAction SilentlyContinue
    }
    else {
        Write-Log "Runner already registered"
    }
}

function Start-Runner {
    Write-Log "Starting runner daemon..."
    & $act_runner_cmd daemon --config $env:CONFIG_FILE
}

try {
    Write-Log "Starting Gitea Runner initialization..."
    Test-Environment
    Register-Runner
    Start-Runner
}
catch {
    Write-Log "Error: $_" -Level ERROR
    throw
}
