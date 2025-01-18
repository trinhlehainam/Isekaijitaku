# References:
# - [UE4 Docker Build Prerequisites](https://github.com/adamrehn/ue4-docker/blob/master/src/ue4docker/dockerfiles/ue4-build-prerequisites/windows/install-prerequisites.ps1)

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
. "$helpersPath/InstallHelpers.ps1"

# Define Visual Studio workloads and components
$vsWorkloadsAndComponents = @{
    # Core components required for builds C++ and .NET applications
    Core = @(
        # MSBuild and core build tools
        "Microsoft.VisualStudio.Workload.MSBuild",
        # C++ build tools
        "Microsoft.VisualStudio.Workload.VCTools",
        # .NET Desktop build tools
        "Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools"
    )
    
    # Required for Rust MSVC toolchain
    Rust = @(
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
        "Microsoft.VisualStudio.Component.Windows11SDK.22621"
    )
    
    # Node.js build tools
    Node = @(
        "Microsoft.VisualStudio.Workload.NodeBuildTools"
    )
}

# Initialize workloads and components list
$finalWorkloadsAndComponents = New-Object System.Collections.Generic.HashSet[string]

# Add components based on installation options
foreach ($option in $vsWorkloadsAndComponents.Keys) {
    $vsWorkloadsAndComponents[$option] | ForEach-Object { $finalWorkloadsAndComponents.Add($_) | Out-Null }
}

# Create installation directory
$installPath = "C:/BuildTools"
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Force -Path $installPath
}

# Install Visual Studio Build Tools with selected components
Write-Host "Installing Visual Studio Build Tools..."
. "$helpersPath/VisualStudioHelpers.ps1"
$VSBuildToolsVersion = "17"
if (-not (Install-VisualStudioBuildTools -InstallPath $installPath -Version $VSBuildToolsVersion -WorkloadsAndComponents $finalWorkloadsAndComponents)) {
    throw "Visual Studio Build Tools installation failed" 
}

# Install Chocolatey if not already installed
if (Get-Command "choco" -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey is already installed"
} else {
    Write-Host "Installing Chocolatey..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

function Start-ProcessSafe {
    param ([string] $cmd, [string[]] $argv)
    Write-Host "Executing command: $cmd $argv"
    $process = Start-Process -NoNewWindow -PassThru -Wait -FilePath $cmd -ArgumentList $argv
    if ($process.ExitCode -ne 0) {
        throw "Exit code: $($process.ExitCode)"
    }
}

# Install the chocolatey packages we need
Start-ProcessSafe "choco" @("install", "--no-progress", "-y", "git.install", "--version=2.43.0", "--params", @'
"'/GitOnlyOnPath /NoAutoCrlf /WindowsTerminal /NoShellIntegration /NoCredentialManager'`"
'@)

Update-Environment

# Forcibly disable the git credential manager
Start-ProcessSafe "git" @("config", "--system", "--unset", "credential.helper")

# Install additional dependencies via Chocolatey
Write-Host "Installing additional build dependencies..."
$chocoPackages = @(
    "choco-cleaner"
)

foreach ($package in $chocoPackages) {
    $params = @("install", $package, "-y", "--no-progress")
    Start-ProcessSafe "choco" $params
}

Update-Environment

# Install Rust (default)
. "$PSScriptRoot/Install-Rust.ps1" -InstallPath $installPath

# Install Node.js and pnpm (default)
. "$PSScriptRoot/Install-NodeJS.ps1" -InstallPath $installPath

Start-ProcessSafe "choco-cleaner" @("--dummy")

# Clean up temp directory
Write-Host "Cleaning up temporary files..."
Remove-Item -Path (Join-Path $env:TEMP "*") -Force -Recurse -ErrorAction SilentlyContinue

Write-Host "Prerequisite build tools installation completed successfully!"