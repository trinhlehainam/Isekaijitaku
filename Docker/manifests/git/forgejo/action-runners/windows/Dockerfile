# References:
# - Gitea Runner: https://gitea.com/gitea/act_runner
# - Gitea Runner Dockerfile: https://gitea.com/gitea/act_runner/src/branch/main/Dockerfile
# - Windows Dotnet Docker Image: https://github.com/dotnet/dotnet-docker
# - Docker Windows Server Core Dockerfile: https://github.com/docker-library/docker/blob/master/27/windows/windowsservercore-ltsc2022/Dockerfile
# - GameCI Windows Base Dockerfile: https://github.com/game-ci/docker/blob/main/images/windows/base/Dockerfile

# Use Windows Server Core as base
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Define gitea_runner_version build argument with default value
ARG gitea_runner_version=0.2.11

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Gitea Runner and dependencies
RUN \
    # Create installation directory
    New-Item -ItemType Directory -Force -Path C:\ProgramData\Gitea-Act-Runner\bin; \
    # Update PATH for Gitea Runner
    \
    $gitea_runner_exec_path = ('{0}\Gitea-Act-Runner\bin' -f $env:ProgramData); \
    Write-Host ('Updating PATH: {0}' -f $gitea_runner_exec_path); \
    $newPath = ('{0};{1}' -f $gitea_runner_exec_path, $env:PATH); \
    [Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine); \
    # Install Chocolatey and required tools
    \
    Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    # Optional: Install Visual Studio Build Tools
    # choco install visualstudio2022-workload-vctools --no-progress -y \
    \
    # Detect CPU architecture
    $osArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture; \
    $arch = switch -Wildcard ($osArch) { \
        '64-bit*' { 'amd64' } \
        'ARM64*' { 'arm64' } \
        default { throw ('Unsupported architecture: {0}' -f $osArch) } \
    }; \
    Write-Host ('Detected OS architecture: {0} (mapped to: {1})' -f $osArch, $arch); \
    \
    # Download and install act_runner
    Write-Host ('Downloading Gitea Runner v{0} for windows-{1}...' -f $env:gitea_runner_version, $arch); \
    $gitea_runner_download_url = 'https://dl.gitea.com/act_runner/{0}/act_runner-{0}-windows-{1}.exe' -f $env:gitea_runner_version, $arch; \
    Write-Host ('Download URL: {0}' -f $gitea_runner_download_url); \
    \
    try { \
        Invoke-WebRequest \
            -Uri $gitea_runner_download_url \
            -OutFile (Join-Path -Path $gitea_runner_exec_path -ChildPath 'act_runner.exe'); \
        \
        $runner_exec_cmd = Join-Path -Path $gitea_runner_exec_path -ChildPath 'act_runner.exe'; \
        if (-not (Test-Path $runner_exec_cmd)) { \
            throw 'Runner executable not found after download' \
        } \
        \
        # Verify the executable
        $runner_version = & $runner_exec_cmd --version; \
        Write-Host ('Runner version: {0}' -f $runner_version); \
    } catch { \
        Write-Error ('Failed to download or verify runner: {0}' -f $_.Exception.Message); \
        throw \
    }

# Copy scripts
COPY scripts/Run.ps1 C:\\ProgramData\\Gitea-Act-Runner\\bin

# Set working directory for runner
WORKDIR C:\\ProgramData\\Gitea-Act-Runner

# Set entrypoint
ENTRYPOINT ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\ProgramData\\Gitea-Act-Runner\\bin\\Run.ps1"]