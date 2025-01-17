# References:
# - https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022
# - https://github.com/MicrosoftDocs/visualstudio-docs/blob/main/docs/install/includes/vs-2022/workload-component-id-vs-community.md
# - https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022
# - https://github.com/adamrehn/ue4-docker/blob/master/src/ue4docker/dockerfiles/ue4-build-prerequisites/windows/install-prerequisites.ps1
#
# Install prerequisites for Unity and Unreal Engine builds
param(
    [string]$VSBuildToolsVersion = "17",
    [string]$WindowsSDKVersion = "20348",
    [string[]]$InstallOptions = @()
)

# Valid installation options
$ValidOptions = @(
    "Unity",
    "Android",
    "UWP"
)

# Stop on first error
$ErrorActionPreference = "Stop"

# Import helpers scripts
$scriptPath = Split-Path -Parent $PSScriptRoot
$helpersPath = Join-Path $scriptPath "helpers"
. (Join-Path $helpersPath "LogHelper.ps1")
. (Join-Path $helpersPath "InstallHelpers.ps1")

# Validate installation options
foreach ($option in $InstallOptions) {
    if ($ValidOptions -notcontains $option) {
        throw "Invalid installation option: $option. Valid options are: $($ValidOptions -join ', ')"
    }
}

function Start-ProcessSafe {
    param ([string] $Cmd, [string[]] $Argv)
    Write-Log "Executing command: $Cmd $Argv"
    $process = Start-Process -NoNewWindow -PassThru -Wait -FilePath $Cmd -ArgumentList $Argv
    if ($process.ExitCode -ne 0) {
        throw "Exit code: $($process.ExitCode)"
    }
}

Install-Chocolatey

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
    "Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools"
)

# Merge all components (removing duplicates)
$vsComponents = @()

# Always include base components
@($vsComponentsCpp, $vsComponentsRust, $vsComponentsDotNet) | ForEach-Object {
    $componentSet = $_
    foreach ($component in $componentSet) {
        if ($vsComponents -notcontains $component) {
            $vsComponents += $component
        }
    }
}

# Add optional components based on InstallOptions array
if ($InstallOptions -contains "Unity") {
    Write-Log "Including Unity development components..."
    foreach ($component in $vsComponentsUnity) {
        if ($vsComponents -notcontains $component) {
            $vsComponents += $component
        }
    }
    $vsWorkloads += "Microsoft.VisualStudio.Workload.ManagedGame"
}

if ($InstallOptions -contains "Android") {
    Write-Log "Including Android development components..."
    foreach ($component in $vsComponentsAndroid) {
        if ($vsComponents -notcontains $component) {
            $vsComponents += $component
        }
    }
}

if ($InstallOptions -contains "UWP") {
    Write-Log "Including UWP development components..."
    foreach ($component in $vsComponentsUWP) {
        if ($vsComponents -notcontains $component) {
            $vsComponents += $component
        }
    }
    $vsWorkloads += "Microsoft.VisualStudio.Workload.UniversalBuildTools"
}

$InstallPath = "C:\BuildTools"

# Install Visual Studio Build Tools
Write-Log "Installing Visual Studio Build Tools..."
$vsInstallerPath = "$InstallPath\Installer"

# Create Installer directory and add to PATH
if (-not (Test-Path $vsInstallerPath)) {
    New-Item -ItemType Directory -Force -Path $vsInstallerPath
}

# Add VS installer to system PATH
Write-Log "Adding Visual Studio installer to system PATH..."
$newPath = ('{0};{1}' -f $vsInstallerPath, $env:PATH)
[Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine)

# Download the Visual Studio installer
Write-Log "Downloading Visual Studio installer..."
$vsBuildtoolsPath = Join-Path $vsInstallerPath "vs_buildtools.exe"
Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $vsBuildtoolsPath

# Install VS Build Tools with required components
$installArgs = @(
    "--quiet",
    "--wait",
    "--norestart",
    "--nocache",
    "--installPath", "$InstallPath",
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
Start-ProcessSafe -Cmd $vsBuildtoolsPath -Argv $installArgs

# Install Rust (default)
Write-Log "Installing Rust..."
$rustupInit = Join-Path $env:TEMP "rustup-init.exe"
Invoke-WebRequest -Uri "https://static.rust-lang.org/rustup/dist/i686-pc-windows-gnu/rustup-init.exe" -OutFile $rustupInit
Start-ProcessSafe -Cmd $rustupInit -Argv @("-y", "--default-toolchain", "stable", "--profile", "minimal")

# Install Node.js and pnpm (default)
Write-Log "Installing Node.js and pnpm..."
$NodeVersion = "22"
choco install nodejs-lts --version=$NodeVersion -y
Write-Log "Enabling pnpm via corepack..."
Start-ProcessSafe -Cmd "corepack" -Argv @("enable", "pnpm")

# Install optional components based on InstallOptions array
if ($InstallOptions -contains "Android") {
    Write-Log "Installing Android SDK and build tools..."
    $androidPath = Join-Path $InstallPath "Android"
    choco install -y android-sdk --params "/ProgramFiles:$androidPath"
}

if ($InstallOptions -contains "Unity") {
    Write-Log "Installing Unity..."
    Import-Module (Join-Path $helpersPath "UnityInstallHelper.psm1")
    Install-UnityEditor -Version "2022.3.16f1" -InstallPath (Join-Path $InstallPath "Unity") `
        -IncludeAndroid:($InstallOptions -contains "Android") `
        -IncludeUWP:($InstallOptions -contains "UWP")
}

# Install additional dependencies via Chocolatey
Write-Log "Installing additional build dependencies..."
$chocoPackages = @(
    "cmake",
    "git"
)

foreach ($package in $chocoPackages) {
    choco install $package -y --no-progress
}

Start-ProcessSafe "choco-cleaner" @("--dummy")

# Clean up temp directory
Write-Log "Cleaning up temporary files..."
Remove-Item -Path (Join-Path $env:TEMP "*") -Force -Recurse -ErrorAction SilentlyContinue

Write-Host "Installation completed successfully!"
