# References:
# - Windows Dotnet Docker Image: https://github.com/dotnet/dotnet-docker
# - Windows Server Core: https://hub.docker.com/r/microsoft/windows-servercore
# - Docker Windows Server Core Dockerfile: https://github.com/docker-library/docker/blob/master/27/windows/windowsservercore-ltsc2022/Dockerfile
# - GameCI Windows Docker Images: https://game.ci/docs/docker/windows-docker-images
# - GameCI Windows Base Dockerfile: https://github.com/game-ci/docker/blob/main/images/windows/base/Dockerfile

FROM mcr.microsoft.com/windows/servercore:ltsc2022

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Chocolatey and required tools
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));
    # Optional: Install Visual Studio Build Tools
    # choco install visualstudio2022-workload-vctools --no-progress -y