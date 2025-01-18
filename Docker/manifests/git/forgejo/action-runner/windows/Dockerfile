# References:
# - Gitea Runner: https://gitea.com/gitea/act_runner
# - Gitea Runner Dockerfile: https://gitea.com/gitea/act_runner/src/branch/main/Dockerfile
# - Windows Server Core: https://hub.docker.com/r/microsoft/windows-servercore
# - Windows SDK Server Core: https://github.com/dotnet/dotnet-docker/blob/main/README.sdk.md
# - Docker Windows Server Core Dockerfile: https://github.com/docker-library/docker/blob/master/27/windows/windowsservercore-ltsc2022/Dockerfile
# - GameCI Docker Images: https://hub.docker.com/r/unityci/hub/tags

# ARG WINDOWS_IMAGE="mcr.microsoft.com/windows/servercore:ltsc2022"
ARG WINDOWS_IMAGE="unityci/hub:windows-3.1.0"
FROM ${WINDOWS_IMAGE}

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG GITEA_RUNNER_VERSION=0.2.11
# Install Gitea Runner
RUN \
    # Create installation directory
    $gitea_runner_exec_path = ('{0}\GiteaActRunner\bin' -f $env:ProgramFiles); \
    New-Item -ItemType Directory -Force -Path $gitea_runner_exec_path; \
    # Update PATH for Gitea Runner
    \
    Write-Host ('Updating PATH: {0}' -f $gitea_runner_exec_path); \
    $newPath = ('{0};{1}' -f $gitea_runner_exec_path, $env:PATH); \
    [Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine); \
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
    Write-Host ('Downloading Gitea Runner v{0} for windows-{1}...' -f $env:GITEA_RUNNER_VERSION, $arch); \
    $gitea_runner_download_url = 'https://dl.gitea.com/act_runner/{0}/act_runner-{0}-windows-{1}.exe' -f $env:GITEA_RUNNER_VERSION, $arch; \
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

COPY ["scripts", "C:/Program Files/GiteaActRunner/scripts"]

WORKDIR C:\\ProgramData\\GiteaActRunner

ENTRYPOINT ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\Program Files\\GiteaActRunner\\scripts\\Run.ps1"]

# Install prerequisite build tools
RUN $scriptPath = ('{0}\GiteaActRunner\scripts' -f $env:ProgramFiles); \
    powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath\build\Install-PrerequisiteBuildTools.ps1"

# Install optional build tools
ARG INSTALL_OPTIONS=""
RUN $scriptPath = ('{0}\GiteaActRunner\scripts' -f $env:ProgramFiles); \
    powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath\build\Install-OptionalBuildTools.ps1" -Options $env:INSTALL_OPTIONS