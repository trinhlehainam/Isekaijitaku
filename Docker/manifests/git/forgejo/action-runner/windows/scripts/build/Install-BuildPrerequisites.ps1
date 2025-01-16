# References:
# - https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022
# - https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022#visual-c-build-tools
# - https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022
# - https://github.com/adamrehn/ue4-docker/blob/master/src/ue4docker/dockerfiles/ue4-build-prerequisites/windows/install-prerequisites.ps1
#
# Install prerequisites for Unity and Unreal Engine builds
param(
    [string]$VSBuildToolsVersion = "17",
    [string]$WindowsSDKVersion = "20348"
)

# Stop on first error
$ErrorActionPreference = "Stop"

# Import module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$helpersPath = Join-Path $scriptPath "helpers"
Import-Module (Join-Path $helpersPath "LogHelper.psm1")

function Start-ProcessSafe
{
    param ([string] $Cmd, [string[]] $Argv)

    Write-Log "Executing comand: $Cmd $Argv"

    $process = Start-Process -NoNewWindow -PassThru -Wait -FilePath $Cmd -ArgumentList $Argv
    if ($process.ExitCode -ne 0)
    {
        throw "Exit code: $($process.ExitCode)"
    }
}

# Install Chocolatey
if (Get-Command "choco" -ErrorAction SilentlyContinue) {
    Write-Log "Chocolatey is already installed"
} else {
    Write-Log "Installing Chocolatey..."
    # NOTE: ExecutionPolicy already set to Bypass in the Dockerfile when running this script
    # Set-ExecutionPolicy Bypass -Scope Process -Force;
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Base C++ Development Components (Required for Rust)
$vsComponentsCpp = @(
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "Microsoft.VisualStudio.Component.Windows11SDK.22621",
    "Microsoft.VisualStudio.Component.VC.CMake.Project",
    "Microsoft.VisualStudio.Component.VC.ATL",
    "Microsoft.VisualStudio.Component.VC.ATLMFC"
)

# Rust-specific Components
# https://rust-lang.github.io/rustup/installation/windows-msvc.html
$vsComponentsRust = @(
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",  # Required for Rust MSVC toolchain
    "Microsoft.VisualStudio.Component.Windows11SDK.22621"
)

# Unity Development Components
$vsComponentsUnity = @(
    "Microsoft.VisualStudio.Workload.ManagedGame",
    "Microsoft.VisualStudio.Component.VC.ASAN",
    "Microsoft.VisualStudio.Component.Windows10SDK.$WindowsSDKVersion",
    "Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64",
    "Microsoft.VisualStudio.Component.VC.14.29.16.11.ARM64",
    "Microsoft.VisualStudio.Component.VC.Redist.14.Latest"
)

# .NET Development Components
$vsComponentsDotNet = @(
    "Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools",
    "Microsoft.VisualStudio.Component.NuGet.BuildTools",
    "Microsoft.Net.Component.4.8.SDK",
    "Microsoft.Net.Component.4.8.TargetingPack",
    "Microsoft.NetCore.Component.Runtime.6.0",
    "Microsoft.NetCore.Component.SDK"
)

# Android Development Components
$vsComponentsAndroid = @(
    "Microsoft.VisualStudio.Component.Android.SDK.Build",
    "Microsoft.VisualStudio.Component.Android.NDK.R23C",
    "Component.Android.SDK.MAUI",
    "Component.OpenJDK"
)

# Universal Windows Platform Components
$vsComponentsUWP = @(
    "Microsoft.VisualStudio.Workload.UniversalBuildTools",
    "Microsoft.VisualStudio.ComponentGroup.UWP.BuildTools",
    "Microsoft.VisualStudio.Component.UWP.VC.ARM64",
    "Microsoft.VisualStudio.Component.UWP.VC.ARM",
    "Microsoft.VisualStudio.Component.Windows10SDK.IpOverUsb",
    "Microsoft.VisualStudio.Component.Windows11SDK.22621"
)

# Core Workloads
$vsWorkloads = @(
    "Microsoft.VisualStudio.Workload.VCTools",
    "Microsoft.VisualStudio.Workload.NetCoreBuildTools",
    "Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools",
    "Microsoft.VisualStudio.Workload.UniversalBuildTools",
    "Microsoft.VisualStudio.Workload.ManagedGame"
)

# Merge all components (removing duplicates)
$vsComponents = @()
@(
    $vsComponentsCpp,
    $vsComponentsRust,
    $vsComponentsUnity,
    $vsComponentsDotNet,
    $vsComponentsAndroid,
    $vsComponentsUWP
) | ForEach-Object {
    $componentSet = $_
    foreach ($component in $componentSet) {
        if ($vsComponents -notcontains $component) {
            $vsComponents += $component
        }
    }
}

# Install Visual Studio Build Tools
Write-Log "Installing Visual Studio Build Tools..."
$vsInstallerPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer"

# Add VS installer to system PATH
Write-Log "Adding Visual Studio installer to system PATH..."
$newPath = ('{0};{1}' -f $vsInstallerPath, $env:PATH)
[Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine)

# Download the Visual Studio installer
Write-Log "Downloading Visual Studio installer..."
$vsBootstrapperUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
$vsBootstrapperPath = Join-Path $env:TEMP "vs_buildtools.exe"
Invoke-WebRequest -Uri $vsBootstrapperUrl -OutFile $vsBootstrapperPath

# Install VS Build Tools with required components
$installArgs = @(
    "--quiet",
    "--wait",
    "--norestart",
    "--nocache",
    "--channelUri", "https://aka.ms/vs/$VSBuildToolsVersion/release/channel",
    "--installChannelUri", "https://aka.ms/vs/$VSBuildToolsVersion/release/channel",
    "--channelId", "VisualStudio.$VSBuildToolsVersion.Release",
    "--productId", "Microsoft.VisualStudio.Product.BuildTools",
    "--locale", "en-US"
)

# Add core workloads
foreach ($workload in $vsWorkloads) {
    $installArgs += "--add"
    $installArgs += $workload
}

# Add all components
foreach ($component in $vsComponents) {
    $installArgs += "--add"
    $installArgs += $component
}

Write-Log "Installing Visual Studio Build Tools and components..."
Start-ProcessSafe -Cmd $vsBootstrapperPath -Argv $installArgs

# Install Rust
Write-Log "Installing Rust..."
$rustupInit = Join-Path $env:TEMP "rustup-init.exe"
Invoke-WebRequest -Uri "https://static.rust-lang.org/rustup/dist/i686-pc-windows-gnu/rustup-init.exe" -OutFile $rustupInit
Start-ProcessSafe -Cmd $rustupInit -Argv @("-y", "--default-toolchain", "stable", "--profile", "minimal")

# Install Android SDK and build tools via Chocolatey
Write-Log "Installing Android SDK and build tools..."
choco install -y android-sdk

# Install Unity Build Support
Write-Log "Installing Unity Build Support dependencies..."
choco install -y --no-progress dotnetfx
choco install -y --no-progress vcredist140
choco install -y --no-progress windows-sdk-10-version-2004-all

# Install additional dependencies via Chocolatey
Write-Log "Installing additional build dependencies..."
$chocoPackages = @(
    "cmake",
    "git",
    "python3"
)

foreach ($package in $chocoPackages) {
    choco install $package -y --no-progress
}

Start-ProcessSafe "choco-cleaner" @("--dummy")

Write-Host "Installation completed successfully!"
