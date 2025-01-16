# References:
# - Windows Dotnet Docker Image: https://github.com/dotnet/dotnet-docker
# - Windows Server Core: https://hub.docker.com/r/microsoft/windows-servercore
# - UE4 Prerequisites: https://github.com/adamrehn/ue4-docker
# - GameCI Windows Docker Images: https://game.ci/docs/docker/windows-docker-images
# - GameCI Windows Base Dockerfile: https://github.com/game-ci/docker/blob/main/images/windows/base/Dockerfile

# Use Windows Server Core LTSC 2022
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Set shell to PowerShell
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Set build arguments
ARG VS_VERSION=2022
ARG VS_BUILD_TOOLS_VERSION=17.8.3
ARG WINDOWS_SDK_VERSION=19041

# Install Chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Copy installation scripts
COPY Install-BuildPrerequisites.ps1 C:/Windows/Temp/

# Install Visual Studio Build Tools and prerequisites
RUN C:/Windows/Temp/Install-BuildPrerequisites.ps1 \
    -VSVersion $env:VS_VERSION \
    -VSBuildToolsVersion $env:VS_BUILD_TOOLS_VERSION \
    -WindowsSDKVersion $env:WINDOWS_SDK_VERSION

# Set environment variables
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
ENV NUGET_XMLDOC_MODE=skip
ENV VS_PATH="C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
ENV VSDEVCMD_PATH="$VS_PATH\Common7\Tools\VsDevCmd.bat"
ENV WindowsSdkDir="C:\Program Files (x86)\Windows Kits\10"
ENV WINDOWS_SDK_VERSION=$WINDOWS_SDK_VERSION

# Create symbolic links for commonly used tools
RUN New-Item -ItemType Directory -Force -Path C:\tools; \
    cmd /c mklink /D "C:\tools\msvc" "${env:VS_PATH}\VC\Tools\MSVC\14.29.30133"; \
    cmd /c mklink /D "C:\tools\sdk" "C:\Program Files (x86)\Windows Kits\10"

# Clean up
RUN Remove-Item -Force -Recurse ${env:TEMP}\*; \
    Remove-Item -Force -Recurse C:\Windows\Temp\*

# Verify installation
RUN Write-Host "Verifying installations..."; \
    cmake --version; \
    git --version; \
    python --version; \
    ninja --version; \
    if (!(Test-Path $env:VS_PATH)) { throw "Visual Studio Build Tools not found" }; \
    if (!(Test-Path "C:\BuildTools\DLLs")) { throw "DLL collection not found" }

WORKDIR C:\workspace