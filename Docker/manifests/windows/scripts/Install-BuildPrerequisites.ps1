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

# Required Visual Studio components for both Unity and Unreal Engine
$vsComponents = @(
    "Microsoft.VisualStudio.Workload.MSBuildTools",
    "Microsoft.VisualStudio.Workload.VCTools",
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "Microsoft.VisualStudio.Component.Windows10SDK.$WindowsSDKVersion",
    "Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64",
    "Microsoft.VisualStudio.Component.VC.14.29.16.11.ARM64",
    "Microsoft.VisualStudio.Component.VC.Redist.14.Latest",
    "Microsoft.VisualStudio.Component.VC.ASAN",
    "Microsoft.VisualStudio.Component.NuGet",
    "Microsoft.VisualStudio.Component.VC.ATL",
    "Microsoft.VisualStudio.Component.VC.ATLMFC"
)

Write-Host "Installing Visual Studio Build Tools $VSBuildToolsVersion..."
$installerUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
$installerPath = Join-Path $env:TEMP "vs_buildtools.exe"

# Download VS Build Tools installer
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

# Prepare installation arguments
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

# Add components to installation arguments
foreach ($component in $vsComponents) {
    $installArgs += "--add"
    $installArgs += $component
}

# Install VS Build Tools
$process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
    Write-Host "Visual Studio Build Tools installation failed with exit code $($process.ExitCode)"
    exit 1
}

# Install additional dependencies via Chocolatey
Write-Host "Installing additional build dependencies..."
$chocoPackages = @(
    "cmake",
    "git",
    "python3"
)

foreach ($package in $chocoPackages) {
    choco install $package -y --no-progress
}

# Create directory for DLL collection
$dllCollectionPath = "C:\BuildTools\DLLs"
New-Item -ItemType Directory -Force -Path $dllCollectionPath

# Collect necessary DLLs from Visual Studio installation
$dllSources = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\$VSVersion\BuildTools\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT",
    "${env:ProgramFiles(x86)}\Windows Kits\10\Redist\$WindowsSDKVersion\ucrt\DLLs\x64"
)

foreach ($source in $dllSources) {
    if (Test-Path $source) {
        Copy-Item -Path "$source\*.dll" -Destination $dllCollectionPath -Force
    }
}

# Remove duplicate DLLs keeping only the latest versions
Get-ChildItem $dllCollectionPath -Filter *.dll | 
    Group-Object BaseName | 
    Where-Object Count -gt 1 | 
    ForEach-Object {
        $_.Group | 
        Sort-Object -Property VersionInfo.FileVersion -Descending | 
        Select-Object -Skip 1 | 
        Remove-Item -Force
    }

Write-Host "Installation completed successfully!"
