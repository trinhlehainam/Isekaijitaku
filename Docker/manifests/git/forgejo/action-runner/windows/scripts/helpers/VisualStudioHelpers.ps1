# References: 
# - [VisualStudioHelpers.ps1](https://github.com/actions/runner-images/blob/main/images/windows/scripts/helpers/VisualStudioHelpers.ps1)
# - [Visual Studio Build Tools Command Line Documentation](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022)
# - [Visual Studio Build Tools Workload Component IDs](https://github.com/MicrosoftDocs/visualstudio-docs/blob/main/docs/install/includes/vs-2022/workload-component-id-vs-build-tools.md)
# - [Visual Studio Command Line Parameters Examples](https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022)

function Install-VisualStudioBuildTools {
    param (
        [string]$InstallPath,
        [string]$Version="17",
        [string[]]$WorkloadsAndComponents = @()
    )

    Write-Host "Installing Visual Studio Build Tools..."

    $vsInstance = Get-VisualStudioBuildToolsInstances -Version $Version | Select-Object -First 1
    $installArgs = @(
        "--channelUri", "https://aka.ms/vs/$Version/release/channel",
        "--installChannelUri", "https://aka.ms/vs/$Version/release/channel",
        "--locale", "en-US"
    )

    if ($vsInstance) {
        $InstallPath = $vsInstance.InstallationPath
        Write-Host "Visual Studio Build Tools $Version is already installed at $InstallPath"
        Write-Host "Use installation path $InstallPath to modify the installation"
        
        $installArgs = @(
            "modify"
        )
    }
    
    # Prepare common installation arguments
    $commonArgs = @(
        "--quiet",
        "--wait",
        "--norestart",
        "--nocache",
        # Visual Studio 2022 Build Tools default installation path is "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
        # This path will break inside argument string so we need to use double quotes
        "--installPath `"$InstallPath`"",
        "--channelId", "VisualStudio.$Version.Release",
        "--productId", "Microsoft.VisualStudio.Product.BuildTools"
    )

    # Add common arguments to installation arguments
    $installArgs += $commonArgs

    # Add workloads and components to installation arguments
    foreach ($id in $WorkloadsAndComponents) {
        $installArgs += "--add $id"
    }

    # Install or modify Visual Studio Build Tools
    Write-Host "Workloads and Components to install/modify: "
    Write-Host "$($WorkloadsAndComponents -join "`n")"
    
    # Download VS Build Tools installer
    $bootstrapperUrl="https://aka.ms/vs/17/release/vs_buildtools.exe"
    $bootstrapperFilePath = (Invoke-DownloadWithRetry $bootstrapperUrl)
    $process = Start-Process -FilePath $bootstrapperFilePath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Warning "Visual Studio Build Tools installation/modification process failed"
        return $false
    }

    # Verify installation path
    $vsInstance = Get-VisualStudioBuildToolsInstances -Version $Version | Select-Object -First 1
    if (-not $vsInstance) {
        Write-Warning "Visual Studio Build Tools installation/modification verification instance not found"
        return $false
    }
    
    # Verify package IDs
    $packageIds = Get-VisualStudioInstancePackageIds -Instance $vsInstance -Version $Version
    foreach ($id in $WorkloadsAndComponents) {
        if (-not $packageIds.Contains($id)) {
            Write-Warning "Visual Studio Build Tools installation/modification verification package ID $id not found"
            return $false
        }
    }

    Write-Host "Visual Studio Build Tools installation/modification completed successfully"
    return $true
}

function Get-VisualStudioBuildToolsInstances {
    param (
        [string]$Version
    )
    
    $vsInstances = Get-VSSetupInstance
    
    Write-Host "Visual Studio instances:"
    foreach ($instance in $vsInstances)  {
        Write-Host "$($instance.DisplayName) in path: $($instance.InstallationPath)"
    }

    # https://github.com/jberezanski/ChocolateyPackages/issues/126
    # Visual Studio 2022 Build Tools default installation path is "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
    return $vsInstances | Where-Object { $_.InstallationVersion.Major -eq $Version -and $_.DisplayName -match "Build Tools" }
}

function Get-VisualStudioInstancePackageIds {
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.VisualStudio.Setup.Instance]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$Version
    )
    # https://stackoverflow.com/a/50983068
    return (Select-VSSetupInstance -Instance $Instance).Packages | Select-Object -ExpandProperty "Id"
}