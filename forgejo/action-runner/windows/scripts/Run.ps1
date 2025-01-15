param(
    [Parameter(Mandatory=$false, ParameterSetName='Install')]
    [ValidateSet('system', 'user')]
    [string]$UserSpace = 'user'
)

# Enable strict error handling
$ErrorActionPreference = 'Stop'

# Import modules
Import-Module "$PSScriptRoot\helpers\LogHelpers.psm1" -Force
Import-Module "$PSScriptRoot\helpers\DotEnvHelper.psm1" -Force

# Constants and paths
$PROGRAM_DIR = if ($UserSpace -eq 'system') {
        "$env:ProgramFiles\GiteaActRunner"
    } else {
        "$env:USERPROFILE\.gitea\act_runner"
    }
$DATA_DIR = if ($UserSpace -eq 'system') {
        "$env:ProgramData\GiteaActRunner"
    } else {
        "$env:USERPROFILE\.gitea\act_runner\data"
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
Import-DotEnv -Path $envFile

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
                Write-Error-Log-And-Throw "Runner registration failed after $max_registration_attempts attempts"
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
    $process_params = @{
        FilePath               = $runnerExe
        ArgumentList           = $params
        NoNewWindow            = $true
        RedirectStandardOutput = "$LOGS_DIR/runner.log"
        RedirectStandardError  = "$LOGS_DIR/runner.error"
        PassThru               = $true
    }
    
    $process = Start-Process @process_params
    Wait-Process -InputObject $process
    Write-Log "Runner exited with code: $($process.ExitCode)"
    exit $process.ExitCode
}
catch {
    Write-ErrorLog "Failed to start runner: $_"
    exit 1
}
finally {
    if ($null -ne $process -and -not $process.HasExited) {
        Write-Log "Killing runner process..."
        Stop-Process -InputObject $process -Force
    } else {
        Write-Log "Runner process already exited"
    }
}