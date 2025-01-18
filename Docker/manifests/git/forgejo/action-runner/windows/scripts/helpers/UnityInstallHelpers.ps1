function Get-UnityChangeSet {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    Write-Host "Validating Unity version $Version..."

    # Check if Node.js is installed
    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        Write-Warning "Node.js is required but not installed. Please install Node.js before proceeding."
        return $null
    }

    # Check if npx is available
    if (-not (Get-Command "npx" -ErrorAction SilentlyContinue)) {
        Write-Warning "npx is required but not installed. Please install npx using 'npm install -g npx' before proceeding."
        return $null
    }

    try {
        # Use npx to run unity-changeset without global installation
        $changeSet = (& npx unity-changeset $Version)
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        return $changeSet
    }
    catch {
        Write-Warning "Failed to validate Unity version: $_"
        return $null
    }
    
    return $null
}

function Install-UnityEditor {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [string]$InstallPath = "C:/BuildTools/Unity/Editor",
        [string[]]$Modules = @("windows-mono", "universal-windows-platform-mono")
    )

    # Validate Unity version
    if (-not (Test-UnityVersion -Version $Version)) {
        throw "Invalid Unity version: $Version"
    }

    # Ensure Unity Hub is installed
    $unityHubPath = Get-UnityHubPath
    
    if (-not $unityHubPath) {
        throw "Unity Hub is not installed. Please install Unity Hub before proceeding."
    }

    # Validate modules
    $validModules = @(
        "windows-mono",
        "windows-il2cpp",
        "universal-windows-platform-mono",
        "android",
        "android-sdk-ndk-tools",
        "ios",
        "webgl",
        "linux-mono",
        "mac-mono"
    )

    foreach ($module in $Modules) {
        if ($validModules -notcontains $module) {
            throw "Invalid module: $module. Valid modules are: $($validModules -join ', ')"
        }
    }

    $changeSet = Get-UnityChangeset -Version $Version

    if (-not $changeSet) {
        throw "Failed to validate Unity version: $Version"
    }

    Write-Host "Chocolatey installation failed, falling back to Unity Hub CLI..."
    # Install editor using Unity Hub CLI
    $editorArgs = @(
        "--headless",
        "install",
        "--version", $Version,
        "--changeset", $changeSet,
        "--module", ($Modules -join " ")
    )

    if ($InstallPath) {
        $editorArgs += "--path"
        $editorArgs += $InstallPath
    }

    Write-Host "Running Unity Hub with args: $($editorArgs -join ' ')"
    $process = Start-Process -FilePath $unityHubPath -ArgumentList $editorArgs -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Unity Editor installation failed with exit code: $($process.ExitCode)"
    }

    # Verify installation
    if (-not (Get-UnityEditorPath -Version $Version)) {
        throw "Unity Editor installation failed - path not found: $editorPath"
    }

    Write-Host "Unity Editor $Version installed successfully at $editorPath"
    return $editorPath
}

function Get-UnityEditorPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $unityEditorPath = "C:/BuildTools/UnityEditor/$Version"
    if (-not (Test-Path $unityEditorPath)) {
        Write-Warning "Unity Editor not found at $unityEditorPath"
        [Environment]::SetEnvironmentVariable("UNITY_EDITOR", $null, [EnvironmentVariableTarget]::Machine)
        return $null
    }
    
    # Set UNITY_EDITOR environment variable to machine to use GameCI actions
    [Environment]::SetEnvironmentVariable("UNITY_EDITOR", $unityEditorPath, [EnvironmentVariableTarget]::Machine)

    return $unityEditorPath
}

function Get-UnityHubPath {
    $unityHubPath = "C:/Program Files/Unity Hub/Unity Hub.exe"
    if (Test-Path $unityHubPath) {
        return $unityHubPath
    }
    
    return $null
}