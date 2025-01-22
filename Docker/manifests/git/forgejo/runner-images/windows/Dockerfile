# References:
# - Windows Server Core: https://hub.docker.com/r/microsoft/windows-servercore
# - Windows SDK Server Core: https://github.com/dotnet/dotnet-docker/blob/main/README.sdk.md
# - Docker Windows Server Core Dockerfile: https://github.com/docker-library/docker/blob/master/27/windows/windowsservercore-ltsc2022/Dockerfile

ARG WINDOWS_IMAGE="mcr.microsoft.com/windows/servercore:ltsc2022"
FROM ${WINDOWS_IMAGE}

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Copy installation scripts
COPY ["windows/build", "C:/Program Files/WindowsRunner/build"]
COPY ["windows/helpers", "C:/Program Files/WindowsRunner/helpers"]
COPY ["windows/Setup.ps1", "C:/Program Files/WindowsRunner/Setup.ps1"]

# Set working directory
WORKDIR "C:/Program Files/WindowsRunner"

# Install build tools and runtimes
RUN powershell -NoProfile -ExecutionPolicy Bypass -File Setup.ps1 && \
    powershell -NoProfile -ExecutionPolicy Bypass -File build/Install-PrerequisiteBuildTools.ps1 && \
    powershell -NoProfile -ExecutionPolicy Bypass -File build/Install-Git.ps1 && \
    powershell -NoProfile -ExecutionPolicy Bypass -File build/Install-NodeJS.ps1 && \
    powershell -NoProfile -ExecutionPolicy Bypass -File build/Install-PythonPrerequisites.ps1 && \
    powershell -NoProfile -ExecutionPolicy Bypass -File build/Install-Rust.ps1 && \
    powershell -NoProfile -ExecutionPolicy Bypass -File build/Install-OptionalBuildTools.ps1

# Clean up
RUN Remove-Item -Path "C:/Program Files/WindowsRunner" -Recurse -Force