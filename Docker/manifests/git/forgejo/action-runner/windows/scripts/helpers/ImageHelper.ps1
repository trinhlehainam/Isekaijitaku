function Install-VisualStudio {
    param (
        [string]$InstallPath,
        [string]$Version,
        [string[]]$Components,
        [string[]]$Workloads
    )

    Write-Host "Installing Visual Studio Build Tools..."
    
    # Download VS Build Tools installer
    $bootstrapperUrl="https://aka.ms/vs/17/release/vs_buildtools.exe"
    $bootstrapperFilePath = Invoke-DownloadWithRetry $bootstrapperUrl

    # Prepare installation arguments
    $installArgs = @(
        "--quiet",
        "--wait",
        "--norestart",
        "--nocache",
        "--installPath", (Join-Path $InstallPath "VS"),
        "--channelUri", "https://aka.ms/vs/$Version/release/channel",
        "--installChannelUri", "https://aka.ms/vs/$Version/release/channel",
        "--channelId", "VisualStudio.$Version.Release",
        "--productId", "Microsoft.VisualStudio.Product.BuildTools",
        "--locale", "en-US"
    )

    # Add workloads
    foreach ($workload in $Workloads) {
        $installArgs += "--add"
        $installArgs += $workload
    }

    # Add components
    foreach ($component in $Components) {
        $installArgs += "--add"
        $installArgs += $component
    }

    # Install Visual Studio Build Tools
    $process = Start-Process -FilePath $bootstrapperFilePath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Visual Studio Build Tools installation failed with exit code: $($process.ExitCode)"
    }
}

function Install-Chocolatey {
    if (Get-Command "choco" -ErrorAction SilentlyContinue) {
        Write-Host "Chocolatey is already installed"
        return
    }

    Write-Host "Installing Chocolatey..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

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
