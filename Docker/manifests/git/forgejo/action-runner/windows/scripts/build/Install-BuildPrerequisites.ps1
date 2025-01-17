# References:
# - [Visual Studio Build Tools Command Line Documentation](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022)
# - [Visual Studio Build Tools Workload Component IDs](https://github.com/MicrosoftDocs/visualstudio-docs/blob/main/docs/install/includes/vs-2022/workload-component-id-vs-build-tools.md)
# - [Visual Studio Community Workload Component IDs](https://github.com/MicrosoftDocs/visualstudio-docs/blob/main/docs/install/includes/vs-2022/workload-component-id-vs-community.md)
# - [Visual Studio Command Line Parameters Examples](https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022)
# - [UE4 Docker Build Prerequisites](https://github.com/adamrehn/ue4-docker/blob/master/src/ue4docker/dockerfiles/ue4-build-prerequisites/windows/install-prerequisites.ps1)
#
# Install prerequisites for Unity and Unreal Engine builds
param(
    [string]$VSBuildToolsVersion = "17",
    [string]$WindowsSDKVersion = "20348",
    [string[]]$InstallOptions = @()
)

# Stop on first error
$ErrorActionPreference = "Stop"

# Install VSSetup module if not already installed
if (-not (Get-Module -ListAvailable -Name VSSetup)) {
    Write-Host "Installing VSSetup module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module VSSetup -Scope CurrentUser -Force
}

# Import helpers scripts
$scriptPath = Split-Path -Parent $PSScriptRoot
$helpersPath = Join-Path $scriptPath "helpers"
. (Join-Path $helpersPath "LogHelpers.ps1")
. (Join-Path $helpersPath "InstallHelpers.ps1")
. (Join-Path $helpersPath "VisualStudioHelpers.ps1")

# Valid installation options
$ValidOptions = @(
    "Unity",
    "Android",
    "UWP"
)

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

# Install Chocolatey if not already installed
if (Get-Command "choco" -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey is already installed"
} else {
    Write-Host "Installing Chocolatey..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Install the chocolatey packages we need
Start-ProcessSafe "choco" @("install", "--no-progress", "-y", "git.install", "--version=2.43.0", "--params", @'
"'/GitOnlyOnPath /NoAutoCrlf /WindowsTerminal /NoShellIntegration /NoCredentialManager'`"
'@)

Update-Environment

# Forcibly disable the git credential manager
Start-ProcessSafe "git" @("config", "--system", "--unset", "credential.helper")

# Install additional dependencies via Chocolatey
Write-Log "Installing additional build dependencies..."
$chocoPackages = @(
    "cmake"
)

foreach ($package in $chocoPackages) {
    $params = @("install", $package, "-y", "--no-progress")
    Start-ProcessSafe "choco" $params
}

# Rust-specific Components
# https://rust-lang.github.io/rustup/installation/windows-msvc.html
$vsComponentsRust = @(
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",  # Required for Rust MSVC toolchain
    "Microsoft.VisualStudio.Component.Windows11SDK.22621"
)

# Unity Build Components
$vsComponentsUnity = @(
    # Build modern C++ apps for Windows using tools of your choice, including MSVC, Clang, CMake, or MSBuild.
    "Microsoft.VisualStudio.Workload.VCTools",
    # Build Android, iOS, Windows, and Mac apps from a single codebase using C# with .NET MAUI.
    "Microsoft.VisualStudio.Workload.XamarinBuildTools",
    # Build applications for the Windows platform using WinUI with C# or optionally C++.
    "Microsoft.VisualStudio.Workload.UniversalBuildTools"
)

# Core Workloads
$vsWorkloadsAndComponentsCore = @(
    "Microsoft.VisualStudio.Workload.MSBuild",
    "Microsoft.VisualStudio.Workload.VCTools",
    "Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools"
)

$vsWorkloadsAndComponents = @()

# Always include base components and workloads
@($vsComponentsRust, $vsWorkloadsAndComponentsCore) | ForEach-Object {
    $componentSet = $_
    foreach ($component in $componentSet) {
        if ($vsWorkloadsAndComponents -notcontains $component) {
            $vsWorkloadsAndComponents += $component
        }
    }
}

# Add optional components based on InstallOptions array
if ($InstallOptions -contains "Unity") {
    Write-Log "Including Unity development components..."
    foreach ($component in $vsComponentsUnity) {
        if ($vsWorkloadsAndComponents -notcontains $component) {
            $vsWorkloadsAndComponents += $component
        }
    }
}

if ($InstallOptions -contains "Android") {
    Write-Log "Including Android development components..."
    foreach ($component in $vsComponentsAndroid) {
        if ($vsWorkloadsAndComponents -notcontains $component) {
            $vsWorkloadsAndComponents += $component
        }
    }
}

if ($InstallOptions -contains "UWP") {
    Write-Log "Including UWP development components..."
    foreach ($component in $vsComponentsUWP) {
        if ($vsWorkloadsAndComponents -notcontains $component) {
            $vsWorkloadsAndComponents += $component
        }
    }
}

$InstallPath = "C:\BuildTools"
# Create BuildTools directory
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Force -Path $InstallPath
}

# Install VS Build Tools with required components
Install-VisualStudio `
    -InstallerPath $InstallPath `
    -Version "17.0" `
    -WorkloadsAndComponents $vsWorkloadsAndComponents

# Install Rust (default)
./Install-Rust.ps1 -InstallPath $InstallPath

# Install Node.js and pnpm (default)
./Install-NodeJS.ps1 -InstallPath $InstallPath

if ($InstallOptions -contains "Unity") {
    Write-Log "Installing Unity..."
    . (Join-Path $helpersPath "UnityInstallHelpers.ps1")
    Install-UnityEditor -Version "2022.3.16f1" -InstallPath (Join-Path $InstallPath "Unity") `
        -IncludeAndroid:($InstallOptions -contains "Android") `
        -IncludeUWP:($InstallOptions -contains "UWP")
}

Start-ProcessSafe "choco-cleaner" @("--dummy")

# Clean up temp directory
Write-Log "Cleaning up temporary files..."
Remove-Item -Path (Join-Path $env:TEMP "*") -Force -Recurse -ErrorAction SilentlyContinue

Write-Host "Installation completed successfully!"