param(
    [Parameter(Mandatory=$false)]
    [AllowEmptyString()]
    [string]$Options
)

if ($Options -eq $null -or $Options -eq "") {
    Write-Host "No options specified"
    exit 0
}

# Stop on first error
$ErrorActionPreference = "Stop"

# Import helpers scripts
$scriptPath = Split-Path -Parent $PSScriptRoot
$helpersPath = Join-Path $scriptPath "helpers"
. "$helpersPath/InstallHelpers.ps1"

# Parse installation options
$parsedOptions = $Options -split ","

# Validate installation options
$validOptions = @("Unity")
foreach ($option in $parsedOptions) {
    if ($validOptions -notcontains $option) {
        throw "Invalid installation option: $option. Valid options are: $($ValidOptions -join ', ')"
    }
}

# Define Visual Studio workloads and components
$vsWorkloadsAndComponents = @{
    # Unity build components
    Unity = @(
        # C++ build tools for Unity
        "Microsoft.VisualStudio.Workload.VCTools",
        # .NET MAUI build tools for cross-platform development
        # "Microsoft.VisualStudio.Workload.XamarinBuildTools",
        # Universal Windows Platform build tools
        "Microsoft.VisualStudio.Workload.UniversalBuildTools"
    )
}

# Initialize workloads and components list
$finalWorkloadsAndComponents = New-Object System.Collections.Generic.HashSet[string]

# Add components based on installation options
foreach ($option in $parsedOptions) {
    if ($vsWorkloadsAndComponents.ContainsKey($option)) {
        Write-Host "Including $option development components..."
        $vsWorkloadsAndComponents[$option] | ForEach-Object { $finalWorkloadsAndComponents.Add($_) | Out-Null }
    }
}

# Create installation directory
$installPath = "C:/BuildTools"
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Force -Path $installPath
}

# Install Visual Studio Build Tools with selected components
Write-Host "Installing Visual Studio Build Tools..."
if ($finalWorkloadsAndComponents.Count -ne 0) {
    $VSBuildToolsVersion = "17"
    . "$helpersPath/VisualStudioHelpers.ps1"
    if (-not (Install-VisualStudioBuildTools -InstallPath $installPath -Version $VSBuildToolsVersion -WorkloadsAndComponents $finalWorkloadsAndComponents)) {
        throw "Visual Studio Build Tools installation failed" 
    }
}

if ($parsedOptions -contains "Unity") {
    Write-Host "Installing Unity..."
    . "$helpersPath/UnityInstallHelpers.ps1"
    # TEST: Install Unity Editor version "2021.3.8f1"
    Install-UnityEditor -Version "2019.4.24f1" -InstallPath (Join-Path $installPath "Unity") -Modules @("universal-windows-platform", "uwp-il2cpp")
}

$process=Start-Process -FilePath "choco-cleaner" -ArgumentList "--dummy" -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "choco-cleaner failed with exit code: $($process.ExitCode)"
}

Write-Host "Optional build tools installation completed successfully!"