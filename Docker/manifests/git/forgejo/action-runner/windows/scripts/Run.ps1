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
        Write-ErrorLog "GITEA_INSTANCE_URL environment variable is required"
        exit 1
    }

    # Check token from environment or file
    if (-not $env:GITEA_RUNNER_REGISTRATION_TOKEN -and $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE) {
        if (Test-Path $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE) {
            try {
                $env:GITEA_RUNNER_REGISTRATION_TOKEN = Get-Content $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE -Raw -ErrorAction Stop
                Write-Log "Successfully read token from file"
            }
            catch {
                Write-ErrorLog "Failed to read token from file: $_"
                exit 1
            }
        }
        else {
            Write-ErrorLog "Token file not found"
            exit 1
        }
    }

    if (-not $env:GITEA_RUNNER_REGISTRATION_TOKEN) {
        Write-ErrorLog "GITEA_RUNNER_REGISTRATION_TOKEN environment variable or GITEA_RUNNER_REGISTRATION_TOKEN_FILE must be provided"
        exit 1
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
        Write-ErrorLog "Specified CONFIG_FILE does not exist: $env:CONFIG_FILE"
        exit 1
    }
}

function New-RunnerConfig {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigFile,

        [Parameter(Mandatory = $false)]
        [string]$RunnerFile,

        [Parameter(Mandatory = $false)]
        [string]$CacheDir,

        [Parameter(Mandatory = $false)]
        [string]$WorkDir,

        [Parameter(Mandatory = $false)]
        [string]$Labels = "windows:host",

        [Parameter(Mandatory = $false)]
        [ValidateSet('trace', 'debug', 'info', 'warn', 'error')]
        [string]$LogLevel = 'info'
    )

    Write-Log "Generating runner configuration..."

    # Create parent directories if they don't exist
    $configDir = Split-Path -Parent $ConfigFile
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    }
    
    # convert labels string from "a,b,c"
    # to
    #   - a
    #   - b
    #   - c
    $labels = $Labels.Trim().Split(",") |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { "    - $_" }

    # convert labels to yaml format
    $labels = $labels -join "`n"

    # Reference: https://gitea.com/gitea/act_runner/src/branch/main/internal/pkg/config/config.example.yaml
    $configContent = @"
# Example configuration file, it's safe to copy this as the default config file without any modification.

# You don't have to copy this file to your instance,
# just run `./act_runner generate-config > config.yaml` to generate a config file.

log:
  # The level of logging, can be trace, debug, info, warn, error, fatal
  level: $LogLevel

runner:
  # Where to store the registration result.
  file: $RunnerFile
  # Execute how many tasks concurrently at the same time.
  capacity: 1
  # Extra environment variables to run jobs.
  envs:
    A_TEST_ENV_NAME_1: a_test_env_value_1
    A_TEST_ENV_NAME_2: a_test_env_value_2
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
$Labels

cache:
  # Enable cache server to use actions/cache.
  enabled: true
  # The directory to store the cache data.
  dir: $CacheDir
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
  workdir_parent: $WorkDir
"@

    try {
        Write-Log "Writing config to: $ConfigFile"
        Set-Content -Path $ConfigFile -Value $configContent -Force
        Write-Log "Config file generated successfully at: $ConfigFile"
    } catch {
        Write-ErrorLog "Failed to write config file: $_"
        exit 1
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
            "--config", $env:CONFIG_FILE,
            "--no-interactive"
        )

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
                exit 1
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
        Write-ErrorLog "Failed to install one or more custom certificates"
        exit 1
    }
    # Because Node.js doesn't use Windows CA certificates by default
    # we need to manually install extra certificates to Node.js
    # https://github.com/nodejs/node/issues/51537
    if (-not (Install-NodeExtraCaCerts -CertFiles $env:EXTRA_CERT_FILES)) {
        Write-ErrorLog "Failed to install one or more custom certificates to Node.js"
        exit 1
    }
    
    # git use OpenSSL by default and extra certificates is installed in Windows CA store
    # need to change git to use Windows CA store
    # https://github.com/desktop/desktop/issues/9293#issuecomment-607357181
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Log "Configuring git to use Windows certificate store for custom certificates..."
        git config --global http.sslBackend schannel
    }
}
    
# change temp file extension to .yaml
# https://stackoverflow.com/a/12120352
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/rename-item?view=powershell-7.4#outputs
$defaultConfigFile = New-TemporaryFile | Rename-Item -NewName { [io.path]::ChangeExtension($_.Name, ".yaml") } -PassThru
    
if ([string]::IsNullOrEmpty($env:CONFIG_FILE) -or -not (Test-Path $env:CONFIG_FILE)) {
    Write-Log "No CONFIG_FILE specified or CONFIG_FILE does not exist, generating default config file..."
    $env:CONFIG_FILE = $defaultConfigFile.FullName
    $defaultRunnerPath = "$env:ProgramData\GiteaActRunner\.runner"
    $defaultCachePath = "$env:ProgramData\GiteaActRunner\.cache\actcache"
    $defaultWorkPath = "$env:ProgramData\GiteaActRunner\.cache\act"
    New-RunnerConfig -ConfigFile $env:CONFIG_FILE -RunnerFile $defaultRunnerPath -CacheDir $defaultCachePath -WorkDir $defaultWorkPath -Labels $env:GITEA_RUNNER_LABELS 
}

Write-Log "Starting Gitea Runner initialization..."
Test-Environment
Register-Runner

Write-Log "Starting runner daemon..."

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

& act_runner daemon --config $env:CONFIG_FILE