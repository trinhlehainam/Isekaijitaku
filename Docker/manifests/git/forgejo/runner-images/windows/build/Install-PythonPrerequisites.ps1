# Install Python prerequisites for GitHub Actions
# This script must be run with administrator privileges
# References:
# - https://github.com/actions/setup-python/blob/main/docs/advanced-usage.md#windows
# - https://github.com/actions/runner-images/blob/main/images/windows/scripts/build/Configure-SystemEnvironment.ps1
# - https://github.com/actions/runner-images/blob/main/images/windows/scripts/build/Install-PyPy.ps1
# - https://github.com/actions/setup-python/blob/main/docs/advanced-usage.md#hosted-tool-cache

[CmdletBinding()]
param()

# Import helper functions
$modulePath = Join-Path $PSScriptRoot ".." "helpers" "InstallHelpers.ps1"
if (-not (Test-Path $modulePath)) {
    throw "Required module not found: $modulePath"
}
. $modulePath

function Install-7Zip {
    Write-Host "Installing 7-Zip..."
    $7zipUrl = 'https://www.7-zip.org/a/7z2301-x64.exe'
    $7zipPath = Join-Path $env:TEMP "7z-setup.exe"
    
    try {
        Invoke-WebRequest -Uri $7zipUrl -OutFile $7zipPath
        $process = Start-Process -FilePath $7zipPath -ArgumentList "/S" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "7-Zip installation failed with exit code: $($process.ExitCode)"
        }

        # Add 7-Zip to PATH if not already present
        $7zipDir = "${env:ProgramFiles}\7-Zip"
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
        if ($currentPath -notlike "*${7zipDir}*") {
            $newPath = "${currentPath};${7zipDir}"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)
        }
    }
    finally {
        Remove-Item -Path $7zipPath -Force -ErrorAction SilentlyContinue
    }
    Write-Host "7-Zip installed successfully"
}

function Set-ExecutionPolicy {
    Write-Host "Setting PowerShell execution policies..."
    
    # Set execution policy for different scopes
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
    
    Write-Host "Current execution policies:"
    Get-ExecutionPolicy -List | Format-Table -AutoSize
}

# Main installation process
try {
    # Verify running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
    }

    Install-7Zip
    Set-ExecutionPolicy

    Write-Host "All Python prerequisites installed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to install Python prerequisites: $_"
    exit 1
}
