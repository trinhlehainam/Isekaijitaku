# References:
# - Gitea Runner: https://gitea.com/gitea/act_runner
# - Gitea Runner Dockerfile: https://gitea.com/gitea/act_runner/src/branch/main/Dockerfile
# - Windows Dotnet Docker Image: https://github.com/dotnet/dotnet-docker
# - Docker Windows Server Core Dockerfile: https://github.com/docker-library/docker/blob/master/27/windows/windowsservercore-ltsc2022/Dockerfile
# - GameCI Windows Base Dockerfile: https://github.com/game-ci/docker/blob/main/images/windows/base/Dockerfile

# Use Windows Server Core as base
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN \
    # Create directories and update PATH
    New-Item -ItemType Directory -Force -Path C:\ProgramData\Gitea-Act-Runner; \
    New-Item -ItemType Directory -Force -Path C:\ProgramData\Gitea-Act-Runner\bin; \
    # Update PATH for Gitea Runner
    \
    $newPath = ('{0}\Gitea-Act-Runner\bin;{1}' -f $env:ProgramData, $env:PATH); \
    Write-Host ('Updating PATH: {0}' -f $newPath); \
    [Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine); \
    # Install Chocolatey and required tools
    \
    Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    choco install -y git 7zip.install; \
    # Optional: Install Visual Studio Build Tools
    # choco install visualstudio2022-workload-vctools --no-progress -y \
    \
    # Install Gitea Runner
    $Version = '0.2.11'; \
    $RunnerPath = 'C:\\ProgramData\\Gitea-Act-Runner\\bin'; \
    New-Item -ItemType Directory -Force -Path $RunnerPath; \
    Invoke-WebRequest \
        -Uri "https://dl.gitea.com/act_runner/$Version/act_runner-$Version-windows-amd64.exe" \
        -OutFile "$RunnerPath\\act_runner.exe"; \
    if (-not (Test-Path "$RunnerPath\\act_runner.exe")) { throw 'Failed to download runner' }

# Copy scripts
COPY scripts/start.ps1 C:/ProgramData/Gitea-Act-Runner/bin/

# Set working directory for runner
WORKDIR C:\\ProgramData\\Gitea-Act-Runner

# Set entrypoint
ENTRYPOINT ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\ProgramData\\Gitea-Act-Runner\\bin\\start.ps1"]