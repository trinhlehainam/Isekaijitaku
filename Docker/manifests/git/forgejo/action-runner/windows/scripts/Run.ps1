# References:
# - Gitea Runner: https://gitea.com/gitea/act_runner
# - Run Script: https://gitea.com/gitea/act_runner/raw/branch/main/scripts/run.sh
# - GitHub Actions Runner Scripts: https://github.com/actions/runner-images/tree/main/images/windows/scripts

# Enable strict error handling
$ErrorActionPreference = 'Stop'

# Import helper scripts
$helpersPath = Join-Path $PSScriptRoot "helpers"
$helpersModule = Import-Module "$helpersPath\ImageRunSetupHelpers.psm1" -PassThru

function Test-Environment {
    Write-Log "Checking environment variables..."
    
    # Check GITEA_INSTANCE_URL
    if (-not $env:GITEA_INSTANCE_URL) {
        Write-Error-Log-And-Throw "GITEA_INSTANCE_URL environment variable is required"
    }

    # Check token from environment or file
    if (-not $env:GITEA_RUNNER_REGISTRATION_TOKEN -and $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE) {
        if (Test-Path $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE) {
            try {
                $env:GITEA_RUNNER_REGISTRATION_TOKEN = Get-Content $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE -Raw -ErrorAction Stop
                Write-Log "Successfully read token from file"
            }
            catch {
                Write-Error-Log-And-Throw "Failed to read token from file: $_"
            }
        }
        else {
            Write-Error-Log-And-Throw "Token file not found"
        }
    }

    if (-not $env:GITEA_RUNNER_REGISTRATION_TOKEN) {
        Write-Error-Log-And-Throw "GITEA_RUNNER_REGISTRATION_TOKEN environment variable or GITEA_RUNNER_REGISTRATION_TOKEN_FILE must be provided"
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
        Write-Error-Log-And-Throw "Specified CONFIG_FILE does not exist: $env:CONFIG_FILE"
    }
}

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

# Install custom certificates if specified
if ($env:EXTRA_CERT_FILES) {
    Write-Log "Installing custom certificates from paths: $env:EXTRA_CERT_FILES"
        if (-not (Install-Certificates -CertFiles $env:EXTRA_CERT_FILES)) {
            Write-Error-Log-And-Throw "Failed to install one or more custom certificates"
        }
}

Write-Log "Starting Gitea Runner initialization..."
Test-Environment
Register-Runner

Write-Log "Starting runner daemon..."
$params = @("daemon")
if ($env:CONFIG_FILE) {
    Write-Log "Using custom config file: $env:CONFIG_FILE"
    $params += @("--config", $env:CONFIG_FILE)
}

# Install VSSetup module if not already installed
if (-not (Get-Module -ListAvailable -Name VSSetup)) {
    Write-Log "Installing VSSetup module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module VSSetup -RequiredVersion 2.2.16 -Scope CurrentUser -Force
}

# Remove unused modules to avoid child process can access them
Remove-Module -ModuleInfo $helpersModule

# Install ImageHelpers module if not already installed
# References:
# - PowerShell Module Installation: https://learn.microsoft.com/en-us/powershell/scripting/developer/module/installing-a-powershell-module
# - Module Path Locations: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath
# - Module Building Basics: https://powershellexplained.com/2017-05-27-Powershell-module-building-basics
# - Installing Custom-Module with Install-Module: https://stackoverflow.com/a/65872546
$moduleName = "ImageHelpers"
$installedModule = Get-Module -Name $moduleName -ListAvailable

if (-not $installedModule) {
    # Get user's PowerShell module directory
    $userModulePath = ($env:PSModulePath -split ';' | Where-Object { $_ -like "$HOME*" }) | Select-Object -First 1
    $moduleInstallPath = Join-Path $userModulePath $moduleName
    
    # Create module directory if it doesn't exist
    if (-not (Test-Path $moduleInstallPath)) {
        New-Item -Path $moduleInstallPath -ItemType Directory -Force | Out-Null
    }
    
    # Define files to exclude
    $filesToExclude = @(
        'ImageRunSetupHelpers.psm1',
        'LogHelpers.ps1',
        'CertificateHelpers.ps1'
    )
    
    # Copy all files except excluded ones
    Get-ChildItem -Path $helpersPath -File | 
        Where-Object { $_.Name -notin $filesToExclude } |
        Copy-Item -Destination $moduleInstallPath -Force
}

& act_runner @params