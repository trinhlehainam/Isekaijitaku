# Import all helper modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperModules = @(
    "LogHelper",
    "UnityInstallHelper"
)

foreach ($module in $helperModules) {
    $modulePath = Join-Path $scriptPath "$module.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        Write-Host "Loaded helper module: $module"
    } else {
        Write-Warning "Helper module not found: $module"
    }
}

function Initialize-BuildEnvironment {
    param (
        [string]$InstallPath = "C:/BuildTools"
    )

    # Ensure installation path exists
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Force -Path $InstallPath
    }

    # Add installation path to system PATH
    $env:PATH = "$InstallPath;$env:PATH"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [System.EnvironmentVariableTarget]::Machine)

    # Create subdirectories for different tools
    $directories = @(
        "VS",
        "Unity",
        "Android",
        "Node",
        "Rust"
    )

    foreach ($dir in $directories) {
        $path = Join-Path $InstallPath $dir
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Force -Path $path
        }
    }
}

Export-ModuleMember -Function Initialize-BuildEnvironment
