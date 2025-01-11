# References:
# - Gitea Runner: https://gitea.com/gitea/act_runner
# - Gitea Runner Dockerfile: https://gitea.com/gitea/act_runner/src/branch/main/Dockerfile
# - Windows Dotnet Docker Image: https://github.com/dotnet/dotnet-docker
# - Docker Windows Server Core Dockerfile: https://github.com/docker-library/docker/blob/master/27/windows/windowsservercore-ltsc2022/Dockerfile
# - GameCI Windows Base Dockerfile: https://github.com/game-ci/docker/blob/main/images/windows/base/Dockerfile

# Use Windows Server Core as base
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Set working directory
WORKDIR C:\\Gitea-Act-Runner

# Switch to CMD for PATH updates
SHELL ["cmd", "/S", "/C"]

# Update PATH and create persistent directories
RUN setx path "C:\ProgramData\GitRunner\apps\bin;%path%" && \
    mkdir C:\ProgramData\GitRunner && \
    mkdir C:\ProgramData\GitRunner\apps

# Switch to PowerShell for installations and setup
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Chocolatey, tools, and runner
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    refreshenv; \
    $env:ChocolateyInstall = 'C:\ProgramData\GitRunner\apps\chocolatey'; \
    choco install -y git 7zip.install --install-directory='C:\ProgramData\GitRunner\apps'; \
    # Optional: Install Visual Studio Build Tools
    # choco install visualstudio2022-workload-vctools --no-progress -y \
    $Version = '0.2.11'; \
    $RunnerPath = 'C:\ProgramData\GitRunner\apps\bin'; \
    New-Item -ItemType Directory -Force -Path $RunnerPath; \
    Invoke-WebRequest \
        -Uri "https://dl.gitea.com/act_runner/$Version/act_runner-$Version-windows-amd64.exe" \
        -OutFile "$RunnerPath\act_runner.exe"; \
    if (-not (Test-Path "$RunnerPath\act_runner.exe")) { throw 'Failed to download runner' }

# Copy scripts
COPY scripts/start.ps1 C:/ProgramData/GitRunner/apps/bin/

# Set working directory for runner
WORKDIR C:\ProgramData\GitRunner\apps\bin

# Set entrypoint
ENTRYPOINT ["powershell", ".\\start.ps1"]