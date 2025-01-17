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
    [string]$Options
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


# Parse installation options
$parsedOptions = $Options -split ","

# Validate installation options
$validOptions = @("Unity", "Rust", "Node")
foreach ($option in $parsedOptions) {
    if ($validOptions -notcontains $option) {
        throw "Invalid installation option: $option. Valid options are: $($ValidOptions -join ', ')"
    }
}

# Define Visual Studio workloads and components
$vsWorkloadsAndComponents = @{
    # Core components required for all builds
    Core = @(
        # MSBuild and core build tools
        "Microsoft.VisualStudio.Workload.MSBuild",
        # C++ build tools
        "Microsoft.VisualStudio.Workload.VCTools",
        # .NET Desktop build tools
        "Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools"
    )
    
    Rust = @(
        # Required for Rust MSVC toolchain
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
        "Microsoft.VisualStudio.Component.Windows11SDK.22621"
    )
    
    # Node.js development tools
    Node = @(
        "Microsoft.VisualStudio.Workload.NodeBuildTools"
    )

    # Unity development components
    Unity = @(
        # C++ build tools for Unity
        "Microsoft.VisualStudio.Workload.VCTools",
        # .NET MAUI build tools for cross-platform development
        "Microsoft.VisualStudio.Workload.XamarinBuildTools",
        # Universal Windows Platform build tools
        "Microsoft.VisualStudio.Workload.UniversalBuildTools"
    )
}

# Initialize workloads and components list
$finalWorkloadsAndComponents = New-Object System.Collections.Generic.HashSet[string]

# Always add core and Rust components
$vsWorkloadsAndComponents.Core | ForEach-Object { $finalWorkloadsAndComponents.Add($_) | Out-Null }
$vsWorkloadsAndComponents.Rust | ForEach-Object { $finalWorkloadsAndComponents.Add($_) | Out-Null }

# Add components based on installation options
foreach ($option in $parsedOptions) {
    if ($vsWorkloadsAndComponents.ContainsKey($option)) {
        Write-Log "Including $option development components..."
        $vsWorkloadsAndComponents[$option] | ForEach-Object { $finalWorkloadsAndComponents.Add($_) | Out-Null }
    }
}

# Create installation directory
$installPath = "C:/BuildTools"
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Force -Path $installPath
}

# Install Visual Studio Build Tools with selected components
Write-Log "Installing Visual Studio Build Tools..."
Install-VisualStudio `
    -InstallPath "$installPath/VisualStudio" `
    -Version $VSBuildToolsVersion `
    -WorkloadsAndComponents $finalWorkloadsAndComponents

# Install VSSetup module if not already installed
if (-not (Get-Module -ListAvailable -Name VSSetup)) {
    Write-Host "Installing VSSetup module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module VSSetup -Scope CurrentUser -Force
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
function Start-ProcessSafe {
    param ([string] $cmd, [string[]] $argv)
    Write-Log "Executing command: $cmd $argv"
    $process = Start-Process -NoNewWindow -PassThru -Wait -FilePath $cmd -ArgumentList $argv
    if ($process.ExitCode -ne 0) {
        throw "Exit code: $($process.ExitCode)"
    }
}

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

# Install Rust (default)
./Install-Rust.ps1 -InstallPath $installPath

# Install Node.js and pnpm (default)
./Install-NodeJS.ps1 -InstallPath $installPath

if ($parsedOptions -contains "Unity") {
    Write-Log "Installing Unity..."
    . (Join-Path $helpersPath "UnityInstallHelpers.ps1")
    Install-UnityEditor -Version "2022.3.16f1" -InstallPath (Join-Path $installPath "Unity") `
        -IncludeAndroid:($parsedOptions -contains "Android") `
        -IncludeUWP:($parsedOptions -contains "UWP")
}

Start-ProcessSafe "choco-cleaner" @("--dummy")

# Clean up temp directory
Write-Log "Cleaning up temporary files..."
Remove-Item -Path (Join-Path $env:TEMP "*") -Force -Recurse -ErrorAction SilentlyContinue

Write-Host "Installation completed successfully!"