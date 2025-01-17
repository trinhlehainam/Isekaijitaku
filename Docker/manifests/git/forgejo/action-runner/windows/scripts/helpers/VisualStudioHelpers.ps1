# Ref: https://github.com/actions/runner-images/blob/main/images/windows/scripts/helpers/VisualStudioHelpers.ps1

function Install-VisualStudio {
    param (
        [string]$InstallPath,
        [string]$Version = "17.0",
        [string[]]$WorkloadsAndComponents = @()
    )

    Write-Host "Installing Visual Studio Build Tools..."

    # Get VS installation information
    # $vsInstallation = Get-VisualStudioPath -Version $Version
    
    # if ($vsInstallation) {
    #     Write-Host "Visual Studio Build Tools $Version is already installed at $vsInstallation"
    #     return $false
    # }

    # Prepare common installation arguments
    $installArgs = @(
        "--quiet",
        "--wait",
        "--norestart",
        "--nocache",
        "--installPath", $InstallPath,
        "--channelUri", "https://aka.ms/vs/$Version/release/channel",
        "--installChannelUri", "https://aka.ms/vs/$Version/release/channel",
        "--channelId", "VisualStudio.$Version.Release",
        "--productId", "Microsoft.VisualStudio.Product.BuildTools",
        "--locale", "en-US"
    )

    # Add workloads and components to installation arguments
    foreach ($id in $WorkloadsAndComponents) {
        $installArgs += "--add"
        $installArgs += $id
    }

    # Download VS Build Tools installer
    $bootstrapperUrl="https://aka.ms/vs/17/release/vs_buildtools.exe"
    $bootstrapperFilePath = (Invoke-DownloadWithRetry $bootstrapperUrl)

    # Install or modify Visual Studio Build Tools
    Write-Host "Workloads and Components to install/modify: $($WorkloadsAndComponents -join ', ')"
    
    $process = Start-Process -FilePath $bootstrapperFilePath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host "Visual Studio Build Tools installation/modification failed with exit code: $($process.ExitCode)"
        return $false
    }

    # Verify installation
    if (-not (Test-VisualStudioInstalled -Version $Version)) {
        Write-Host "Visual Studio installation verification failed"
        return $false
    }

    Write-Host "Visual Studio Build Tools installation/modification completed successfully"
    return $true
}

function Get-VisualStudioPath {
    param (
        [string]$Version = "17"
    )

    $vsInstance = Get-VSSetupInstance | 
        Where-Object { $_.InstallationVersion.Major -eq $Version } |
        Select-Object -First 1

    if (-not $vsInstance) {
        Write-Host "Visual Studio $Version is not installed"
        return $null
    }

    return $vsInstance.InstallationPath
}

function Test-VisualStudioInstalled {
    param (
        [string]$Version = "17"
    )

    return $null -ne (Get-VSSetupInstance | 
        Where-Object { $_.InstallationVersion.Major -eq $Version } |
        Select-Object -First 1)
}