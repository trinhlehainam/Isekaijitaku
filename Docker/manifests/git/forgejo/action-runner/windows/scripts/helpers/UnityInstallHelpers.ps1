function Get-UnityChangeSet {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    Write-Host "Validating Unity version $Version..."

    # Check if Node.js is installed
    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        Write-Error "Node.js is required but not installed. Please install Node.js before proceeding."
        return $null
    }

    # Check if npx is available
    if (-not (Get-Command "npx" -ErrorAction SilentlyContinue)) {
        Write-Error "npx is required but not installed. Please install npx using 'npm install -g npx' before proceeding."
        return $null
    }

    # Use npx to run unity-changeset without global installation
    $changeSet = (& npx unity-changeset $Version)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to validate Unity version: $Version"
        return $null
    }
    
    return $changeSet
}

function Install-UnityEditor {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [string]$InstallPath = "C:/BuildTools/UnityEditor",
        [string[]]$Modules = @("windows-mono", "universal-windows-platform-mono")
    )

    # Ensure Unity Hub is installed
    $unityHubPath = Get-UnityHubPath
    
    if (-not $unityHubPath) {
        Write-Error "Unity Hub is not installed. Please install Unity Hub before proceeding."
        return $false
    }

    if (-not (Set-UnityEditorInstallPath -Path $InstallPath)) {
        Write-Error "Failed to set Unity Hub install path to $InstallPath"
        return $false
    }

    # Validate Unity version
    if (-not (Get-UnityChangeSet -Version $Version)) {
        Write-Error "Invalid Unity version: $Version"
        return $false
    }

    # Validate modules
    # https://docs.unity3d.com/hub/manual/HubCLI.html#available-modules
    $validModules = @(
        "windows",
        "windows-mono",
        "universal-windows-platform",
        "uwp-il2cpp",
        "uwp-.net",
        "android",
        "android-sdk-ndk-tools",
        "ios",
        "webgl",
        "linux-mono",
        "mac-mono"
    )

    foreach ($module in $Modules) {
        if ($validModules -notcontains $module) {
            Write-Error "Invalid module: $module. Valid modules are: $($validModules -join ', ')"
            return $false
        }
    }

    $changeSet = Get-UnityChangeSet -Version $Version

    if (-not $changeSet) {
        Write-Error "Failed to validate Unity version: $Version"
        return $false
    }

    # Install editor using Unity Hub CLI
    # https://docs.unity3d.com/hub/manual/HubCLI.html#install-unity-editors
    $installArgs = @(
        "--"
        "--headless",
        "install",
        "--version", $Version,
        "--changeset", $changeSet,
        "--module", ($Modules -join " ")
    )

    Write-Host "Running Unity Hub with args: $($installArgs -join ' ')"
    $process = Start-Process -FilePath $unityHubPath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Unity Editor installation failed with exit code: $($process.ExitCode)"
        return $false
    }

    # Verify installation
    if (-not (Get-UnityEditorPath -Version $Version)) {
        Write-Error "Unity Editor installation failed - path not found: $editorPath"
        return $false
    }

    Write-Host "Unity Editor $Version installed successfully at $editorPath"
    return $true
}

function Set-UnityEditorInstallPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    Write-Host "Starting to set Unity Hub install path to: $Path"

    $unityHubPath = Get-UnityHubPath
    if (-not $unityHubPath) {
        Write-Error "Unity Hub is not installed. Please install Unity Hub before proceeding."
        return $false
    }
    
    # Create directory if it doesn't exist
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path
        if (Test-Path -Path $Path) {
            Write-Host "Created directory: $Path"
        } else {
            Write-Error "Failed to create directory: $Path"
            return $false
        }
    }

    $installArgs = @(
        "--"
        "--headless",
        "install-path",
        "--set", $Path
    )

    $process = Start-Process -FilePath $unityHubPath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Failed to set Unity Hub install path: $($process.ExitCode)"
        return $false
    }
    
    Write-Host "Successfully set Unity Hub install path to: $Path"
    return $true
}

function Get-UnityEditorPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $unityEditorPath = "C:/BuildTools/UnityEditor/$Version"
    if (-not (Test-Path $unityEditorPath)) {
        Write-Error "Unity Editor not found at $unityEditorPath"
        [Environment]::SetEnvironmentVariable("UNITY_EDITOR", $null, [EnvironmentVariableTarget]::Machine)
        return $null
    }
    
    # Set UNITY_EDITOR environment variable to machine to use GameCI actions
    [Environment]::SetEnvironmentVariable("UNITY_EDITOR", $unityEditorPath, [EnvironmentVariableTarget]::Machine)

    return $unityEditorPath
}

function Get-UnityHubPath {
    $unityHubPath = "$env:ProgramFiles/Unity Hub/Unity Hub.exe"
    if (-not (Test-Path $unityHubPath)) {
        Write-Error "Unity Hub not found at $unityHubPath"
        return $null
    }
    
    return $unityHubPath
}