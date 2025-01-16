function Install-UnityHub {
    param (
        [string]$InstallPath = "C:/BuildTools/Unity"
    )

    Write-Host "Installing Unity Hub..."
    $unityHubSetup = Join-Path $env:TEMP "UnityHubSetup.exe"
    
    # Download Unity Hub
    Invoke-WebRequest -Uri "https://public-cdn.cloud.unity3d.com/hub/prod/UnityHubSetup.exe" -OutFile $unityHubSetup
    
    # Install Unity Hub silently
    Start-Process -FilePath $unityHubSetup -ArgumentList "/S" -Wait
    
    # Add Unity Hub to PATH
    $unityHubPath = "${env:LocalAppData}\UnityHub"
    $env:PATH = "$unityHubPath;$env:PATH"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [System.EnvironmentVariableTarget]::Machine)
}

function Install-UnityEditor {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$InstallPath = "C:/BuildTools/Unity",
        [string[]]$Modules = @("windows-mono", "windows-il2cpp"),
        [switch]$IncludeAndroid,
        [switch]$IncludeUWP
    )

    # Check if Unity Hub is installed
    $unityHub = "${env:LocalAppData}\UnityHub\Unity Hub.exe"
    if (-not (Test-Path $unityHub)) {
        Install-UnityHub -InstallPath $InstallPath
    }

    Write-Host "Installing Unity Editor version $Version..."

    # Create installation directory
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Force -Path $InstallPath
    }

    # Prepare modules list
    $moduleArgs = @()
    foreach ($module in $Modules) {
        $moduleArgs += "--module"
        $moduleArgs += $module
    }

    if ($IncludeAndroid) {
        $moduleArgs += "--module"
        $moduleArgs += "android"
    }

    if ($IncludeUWP) {
        $moduleArgs += "--module"
        $moduleArgs += "uwp"
        $moduleArgs += "--module"
        $moduleArgs += "uwp-support"
    }

    # Install Unity Editor
    $unityHubArgs = @(
        "--headless",
        "install",
        "--version", $Version,
        "--childModules",
        "--installPath", $InstallPath
    ) + $moduleArgs

    Start-Process -FilePath $unityHub -ArgumentList $unityHubArgs -Wait -NoNewWindow
}

Export-ModuleMember -Function Install-UnityHub, Install-UnityEditor
