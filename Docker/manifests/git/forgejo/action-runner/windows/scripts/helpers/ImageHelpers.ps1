function Install-AndroidSDK {
    param (
        [string]$InstallPath
    )

    Write-Host "Installing Android SDK..."
    $androidPath = Join-Path $InstallPath "Android"
    choco install -y android-sdk --params "/ProgramFiles:$androidPath"

    # Add to PATH
    $env:PATH = "$androidPath\tools;$androidPath\platform-tools;$env:PATH"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [System.EnvironmentVariableTarget]::Machine)
}

function Install-CommonTools {
    param (
        [string[]]$Tools = @("git", "cmake")
    )

    Write-Host "Installing common tools..."
    foreach ($tool in $Tools) {
        choco install $tool -y --no-progress
    }
}

function Clear-TempFiles {
    Write-Host "Cleaning temporary files..."
    Remove-Item -Path (Join-Path $env:TEMP "*") -Force -Recurse -ErrorAction SilentlyContinue
    Start-Process "choco-cleaner" -ArgumentList @("--dummy") -NoNewWindow -Wait
}
