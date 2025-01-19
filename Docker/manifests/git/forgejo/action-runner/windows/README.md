# Windows Gitea Action Runner

## Important Notice About Windows Container Support

> **Note**: As of January 2024, Gitea Action Runner has limited support for running actions in Windows Containers. 
> For tracking this limitation, see:
> - [act_runner issue #467: Support running actions in Windows containers](https://gitea.com/gitea/act_runner/issues/467)
> - [actions/runner issue #904: Windows Container Support](https://github.com/actions/runner/issues/904)

Due to these limitations, we recommend two approaches:

1. **Custom Windows Container Base Image**:
   - Build a custom Windows container with all required tools pre-installed
   - Use this as base image for running actions
   - Note: Limited functionality due to current container support issues

2. **VM-based Installation (Recommended)**:
   - Run Gitea Action Runner directly on a dedicated Windows VM
   - Provides better isolation and security
   - Full Windows environment support

This repository contains the Dockerfile and configuration for running Gitea Action Runner on Windows containers, which will be fully functional once container support is improved.

## Directory Structure

```
windows/
├── Dockerfile              # Container definition using unityci/hub:windows base image
├── docker-compose.yaml     # Docker Compose configuration
├── README.md              # This documentation
├── runner/                # Runner-specific files
└── scripts/               # Installation and configuration scripts
    ├── Run.ps1            # Main entry point script
    ├── build/             # Build tool installation scripts
    │   ├── Install-NodeJS.ps1
    │   ├── Install-OptionalBuildTools.ps1
    │   ├── Install-PrerequisiteBuildTools.ps1
    │   └── Install-Rust.ps1
    └── helpers/           # Helper functions and utilities
        ├── CertificateHelpers.ps1
        ├── ImageHelpers.ps1
        ├── ImageHelpers.psm1
        ├── InstallHelpers.ps1
        ├── LogHelpers.ps1
        ├── UnityInstallHelpers.ps1
        └── VisualStudioHelpers.ps1
```

## Features

### Development Environments

The container supports multiple development environments:

1. **Unity Development**
   - Unity Hub and Editor installation
   - Visual Studio Build Tools with Unity workload
   - .NET and C++ development tools

2. **Rust Development**
   - Rust toolchain installation
   - MSVC build tools
   - Windows SDK components

3. **Node.js Development**
   - Node.js runtime
   - npm package manager
   - Build tools for native modules

### Installation Options

The build environment is customizable through installation options:

```powershell
# Available options: Unity, Rust, Node
-Options "Unity,Rust,Node"
```

### Visual Studio Components

The build environment includes Visual Studio Build Tools with components organized by development type:

#### Core Components (Always Installed)
- MSBuild and core build tools
- C++ build tools
- .NET Desktop build tools

#### Rust Components
- MSVC toolchain
- Windows 11 SDK

#### Node.js Components
- Node.js build tools
- Native module build support

#### Unity Components
- C++ build tools for Unity
- .NET MAUI build tools
- Universal Windows Platform build tools

## Base Image

The container uses `unityci/hub:windows-3.1.0` as the base image, which provides:
- Windows Server Core base
- Unity Hub pre-installed
- Essential build tools

## Quick Start

1. Create `.env` file:
```env
GITEA_INSTANCE_URL=http://gitea:3000
GITEA_RUNNER_REGISTRATION_TOKEN=your_token_here
```

2. Build and run:
```powershell
# Build with specific Gitea runner version
docker compose build --build-arg gitea_runner_version=0.2.11

# Start the runner
docker compose up -d
```

## Configuration

### Environment Variables

Required:
- `GITEA_INSTANCE_URL`: URL of your Gitea instance
- `GITEA_RUNNER_REGISTRATION_TOKEN`: Runner registration token

Optional:
- `GITEA_RUNNER_NAME`: Name for the runner (default: hostname)
- `GITEA_RUNNER_LABELS`: Labels for the runner (default: windows:host)
- `CONFIG_FILE`: Custom config file path
- `GITEA_MAX_REG_ATTEMPTS`: Maximum registration attempts (default: 10)

### Security Notes
- Running the runner directly on host gives it full system access
- For production environments:
  - Use dedicated VMs (current recommended approach)
  - Or custom Windows containers (when container support improves)
- Never run untrusted actions on production systems
- Regularly update runner and base images/VMs
- Registration token is automatically removed from environment after successful registration
- Token file remains accessible for container restarts
- Environment variables are validated before use
- TLS certificate verification enabled by default

### Default Paths
- Runner state file: `.runner` in runner's working directory (can be overridden with `RUNNER_STATE_FILE`)
- Cache directory: `$HOME/.cache/actcache` if not specified in config
- Work directory: `$HOME/.cache/act` if not specified in config
- Config file: `config.yaml` in runner's working directory

```ad-note
In Windows Server Core container, `$HOME` is `C:\Users\ContainerAdministrator`
```

### Runner Configuration

The runner uses a configuration file (`config.yaml`) with the following key settings:

```yaml
log:
  level: info  # Logging level: trace, debug, info, warn, error, fatal

runner:
  file: .runner  # Registration state file
  capacity: 1    # Concurrent task limit
  timeout: 3h    # Job execution timeout
  shutdown_timeout: 3h  # Graceful shutdown timeout
  insecure: false  # TLS verification
  fetch_timeout: 5s  # Job fetch timeout
  fetch_interval: 2s  # Job fetch interval
  report_interval: 1s  # Status report interval
  labels:  # Runner capabilities
    - "windows:host"

cache:
  enabled: true
  dir: .cache
  host: ""
  port: 0
```

#### Build Arguments

- `GITEA_RUNNER_VERSION`: Version of Gitea runner to install (e.g., "0.2.11")
- `WINDOWS_IMAGE`: Base Windows image to use (default: "mcr.microsoft.com/windows/servercore:ltsc2022")
  - Use your custom Windows image: `your-registry/your-custom-windows-image:tag`
  - Or use official Microsoft image: `mcr.microsoft.com/windows/servercore:ltsc2022`

#### Example docker-compose.yaml
```yaml
services:
  gitea-runner:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        GITEA_RUNNER_VERSION: 0.2.11
        WINDOWS_IMAGE: your-registry/your-custom-windows-image:latest
    image: gitea-runner-windows:0.2.11
    environment:
      - GITEA_INSTANCE_URL=http://gitea:3000
      - GITEA_RUNNER_REGISTRATION_TOKEN=your_token_here
      - GITEA_RUNNER_NAME=windows-container-gitea-runner
      - GITEA_RUNNER_LABELS=windows:host
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
    restart: unless-stopped
```

### Custom CA Certificates

The runner supports installing custom CA certificates during startup using the `EXTRA_CERT_FILES` environment variable. You can specify:

- Individual certificate files
- Directories containing certificates
- A combination of both

Use commas to separate multiple paths:
```
EXTRA_CERT_FILES=C:\certs\root-ca.crt,C:\certs\intermediate-ca.crt,C:\all-certs
```

Example docker-compose.yaml:
```yaml
services:
  gitea-runner:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        GITEA_RUNNER_VERSION: 0.2.11
        WINDOWS_IMAGE: your-registry/your-custom-windows-image:latest
    image: gitea-runner-windows:0.2.11
    environment:
      - GITEA_INSTANCE_URL=http://gitea:3000
      - GITEA_RUNNER_REGISTRATION_TOKEN=your_token_here
      - GITEA_RUNNER_NAME=windows-container-gitea-runner
      - GITEA_RUNNER_LABELS=windows:host
      # Multiple certificate paths (files and directories)
      - EXTRA_CERT_FILES=C:\certs\root-ca.crt,C:\certs\intermediate-ca.crt,C:\all-certs
    volumes:
      - ./certs/root-ca.crt:C:\certs\root-ca.crt:ro
      - ./certs/intermediate-ca.crt:C:\certs\intermediate-ca.crt:ro
      - ./all-certs:C:\all-certs:ro
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
    restart: unless-stopped
```

The certificate installation process:
1. Processes each path in the comma-separated list
2. For each path:
   - If it's a file: installs the certificate directly
   - If it's a directory: installs all certificates in the directory and subdirectories
3. Supports multiple certificate formats (.cer, .crt, .pem)
4. Automatically selects appropriate certificate store:
   - CA store for CA certificates
   - Personal store for certificates with private keys
5. Provides detailed logging for each certificate installation
6. Continues processing remaining paths if one fails
7. Returns non-zero exit code if any certificate fails to install

### Build Examples

```powershell
# Build with default Windows image
docker compose build --build-arg GITEA_RUNNER_VERSION=0.2.11

# Build with custom Windows base image
docker compose build \
    --build-arg GITEA_RUNNER_VERSION=0.2.11 \
    --build-arg WINDOWS_IMAGE=your-registry/your-custom-windows-image:latest

# Build with specific version and tag
docker compose build \
    --build-arg GITEA_RUNNER_VERSION=0.2.11 \
    --build-arg WINDOWS_IMAGE=your-registry/your-custom-windows-image:1.0.0 \
    gitea-runner

### Resource Management

Windows containers support resource limits but not reservations. Setting memory reservations will result in the error:
```
Error response from daemon: invalid option: Windows does not support MemoryReservation
```

You can set resource limits in `docker-compose.yaml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
```

## Build Prerequisites

The `Install-BuildPrerequisites.ps1` script manages the installation of all development tools and SDKs.

### Installation Options

```powershell
.\Install-BuildPrerequisites.ps1 [options]

Options:
  -VSBuildToolsVersion     Visual Studio Build Tools version (default: "17")
  -WindowsSDKVersion       Windows SDK version (default: "20348")
  -InstallUnity           Install Unity build support (default: false)
  -InstallAndroid         Install Android development tools (default: false)
  -InstallUWP             Install UWP development tools (default: false)
  -NodeVersion            Node.js LTS version to install (default: "22")
```

### Default Components

The following components are installed by default:

1. **Base Development Tools**
   - Visual Studio Build Tools 2022
   - C++ build tools and Windows SDK
   - .NET development tools
   - CMake and Git

2. **Node.js Environment**
   - Node.js LTS (default v22)
   - pnpm package manager (via corepack)

3. **Rust Development**
   - Latest stable Rust toolchain
   - MSVC build tools
   - Cargo package manager

### Optional Components

1. **Unity Development** (`-InstallUnity`)
   - Unity Build Support components
   - IL2CPP build support
   - Windows build support
   - Android build support
   - Required Visual C++ components
   - .NET Framework support

2. **Android Development** (`-InstallAndroid`)
   - Android SDK
   - Android NDK R23C
   - .NET MAUI support
   - OpenJDK

3. **Universal Windows Platform** (`-InstallUWP`)
   - UWP build tools
   - ARM64 and ARM support
   - Windows 11 SDK
   - USB device connectivity support

### Example Usage

```powershell
# Install with default components only
.\Install-BuildPrerequisites.ps1

# Install with Unity and Android support
.\Install-BuildPrerequisites.ps1 -InstallUnity -InstallAndroid

# Install all components
.\Install-BuildPrerequisites.ps1 -InstallUnity -InstallAndroid -InstallUWP

# Install with specific Node.js version
.\Install-BuildPrerequisites.ps1 -NodeVersion "18"
```

## Visual Studio Build Tools Components

The build environment includes Visual Studio Build Tools with various components organized by development type. The installation process supports both fresh installations and modifications of existing installations.

### Core Components (Always Installed)
- MSBuild and core build tools
- C++ build tools
- .NET Desktop build tools
- Rust MSVC toolchain support
- Windows 11 SDK

### Unity Development Components
- C++ build tools for Unity
- .NET MAUI build tools for cross-platform development
- Universal Windows Platform build tools

### Android Development Components
- Mobile development with .NET
- Android SDK setup
- Android NDK (R23C)

### UWP Development Components
- Universal Windows Platform build tools
- Windows 11 SDK

### Installation and Modification

The installation process automatically detects if Visual Studio is already installed:
- For fresh installations, it performs a complete installation with selected components
- For existing installations, it modifies the installation to add new components

```powershell
# Fresh installation with Unity and Android support
./Install-BuildPrerequisites.ps1 -InstallOptions @("Unity", "Android")

# Add UWP support to existing installation
./Install-BuildPrerequisites.ps1 -InstallOptions @("UWP")
```

### Component Organization

Components are organized in a structured hashtable for better maintainability:

```powershell
$vsComponents = @{
    Core = @(
        "Microsoft.VisualStudio.Workload.MSBuild",
        "Microsoft.VisualStudio.Workload.VCTools",
        "Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "Microsoft.VisualStudio.Component.Windows11SDK.22621"
    )
    Unity = @(
        "Microsoft.VisualStudio.Workload.VCTools",
        "Microsoft.VisualStudio.Workload.XamarinBuildTools",
        "Microsoft.VisualStudio.Workload.UniversalBuildTools"
    )
    # ... other component groups
}
```

Core components are always installed, while additional components are added based on the specified installation options. The installation process uses a HashSet to ensure no duplicate components are installed.

### Installation Path Structure

```
C:/BuildTools/
├── VisualStudio/        # Visual Studio Build Tools
├── Unity/              # Unity installation
└── Android/            # Android SDK and tools
```

## Unity Development Support

The runner includes support for Unity development through Unity Hub CLI. The installation process is managed by helper scripts that handle both Unity Hub and Unity Editor installation.

### Prerequisites

Before using the Unity installation scripts, ensure you have the following dependencies installed:

1. **Required Dependencies**:
   - Node.js: Required for version validation
   - npx: Required for unity-changeset validation
   - Chocolatey: Required for Unity Hub and Editor installation

2. **Installation Commands**:
   ```powershell
   # Install Chocolatey (if not installed)
   Set-ExecutionPolicy Bypass -Scope Process -Force
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
   iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

   # Install Node.js
   choco install nodejs -y

   # Install npx globally
   npm install -g npx
   ```

### Unity Installation Features

1. **Unity Hub Installation**
   - Automated silent installation
   - Default installation path: `C:/BuildTools/Unity`
   - Automatic PATH environment variable configuration

2. **Unity Editor Installation**
   - Version validation using `unity-changeset`
   - Configurable installation path
   - Flexible module selection
   - Default modules: Windows-Mono and UWP support

### Usage Examples

```powershell
# Install Unity Hub
Install-UnityHub -InstallPath "C:/BuildTools/Unity"

# Install Unity Editor with specific modules
Install-UnityEditor `
    -Version "2022.3.16f1" `
    -InstallPath "C:/BuildTools/Unity/Editor" `
    -Modules @(
        "windows-mono",
        "universal-windows-platform-mono",
        "android",
        "android-sdk-ndk-tools"
    )

# Get Unity installation paths
$unityEditorPath = Get-UnityEditorPath -Version "2022.3.16f1" -InstallPath "C:/BuildTools/Unity/Editor"

# Validate Unity version
Test-UnityVersion -Version "2022.3.16f1"
```

### Available Modules

The following modules can be specified in the `-Modules` parameter:

- `windows-mono`: Windows Build Support (Mono)
- `windows-il2cpp`: Windows Build Support (IL2CPP)
- `universal-windows-platform-mono`: Universal Windows Platform Support
- `android`: Android Build Support
- `android-sdk-ndk-tools`: Android SDK & NDK Tools
- `ios`: iOS Build Support
- `webgl`: WebGL Build Support
- `linux-mono`: Linux Build Support
- `mac-mono`: macOS Build Support

### Installation Paths

```
C:/BuildTools/Unity/                  # Unity Hub installation
└── Unity Hub.exe                     # Unity Hub executable
C:/BuildTools/Unity/Editor/           # Unity Editor installation
└── [VERSION]/                        # Editor version-specific files
    ├── Editor/                       # Unity Editor
    └── modules/                      # Installed modules
```

## Helper Scripts

The runner uses a modular helper script system located in the `scripts/helpers` directory:

### Core Helpers

1. **ImageHelper.ps1**
   - Core image setup and tool installation functions
   - Environment initialization
   - Tool installation methods:
     - Visual Studio Build Tools
     - Node.js and pnpm
     - Rust toolchain
     - Android SDK
     - Common development tools

2. **ImageHelper.psm1**
   - PowerShell module loader
   - Imports and exports all helper functions
   - Manages dependencies between helper scripts

3. **UnityInstallHelper.psm1**
   - Unity-specific installation functions
   - Unity Hub installation and configuration
   - Unity Editor installation with modules

### Available Functions

#### Image Setup
```powershell
# Initialize build environment
Initialize-BuildEnvironment -InstallPath "C:/BuildTools"

# Install Visual Studio
Install-VisualStudio -InstallPath $path -Version "17" -Components $components -Workloads $workloads

# Install Node.js
Install-NodeJs -InstallPath $path -Version "22" -InstallPnpm

# Install Rust
Install-Rust -InstallPath $path -Toolchain "stable" -Profile "minimal"

# Install Android SDK
Install-AndroidSDK -InstallPath $path

# Install Unity
Install-UnityEditor -Version "2022.3.16f1" -InstallPath $path -Modules @("windows-mono", "universal-windows-platform-mono")
```

#### Environment Management
```powershell
# Install common tools
Install-CommonTools -Tools @("git", "cmake")

# Clean temporary files
Clear-TempFiles
```

### Directory Structure

The build tools are organized in a standard directory structure under `C:/BuildTools`:
```
C:/BuildTools/
├── VS/              # Visual Studio Build Tools
├── Unity/           # Unity Editor and Hub
├── Android/         # Android SDK and NDK
├── Node/            # Node.js and npm/pnpm
├── Rust/            # Rust toolchain
└── Tools/           # Common development tools
```

## Build Capabilities

The runner is equipped with comprehensive build tools and SDKs to support various development scenarios:

### Development Environments

1. **C++ Development**
   - Visual Studio Build Tools 2022
   - CMake build system
   - ATL/MFC support
   - Windows SDK 11
   - Address Sanitizer (ASAN)

2. **Rust Development**
   - Latest stable Rust toolchain
   - MSVC build tools
   - Cargo package manager

3. **Unity Development**
   - Unity Build Support components
   - IL2CPP build support
   - Windows build support
   - Android build support
   - Required Visual C++ components
   - .NET Framework support

4. **.NET Development**
   - .NET Framework 4.8 SDK
   - .NET Core 6.0 Runtime
   - NuGet package manager
   - MSBuild Tools

5. **Android Development**
   - Android SDK
   - Android NDK R23C
   - .NET MAUI support
   - OpenJDK
   - Cross-platform build support

6. **Universal Windows Platform (UWP)**
   - UWP build tools
   - ARM64 and ARM support
   - Windows 11 SDK
   - USB device connectivity support

### Additional Tools

- Git for Windows
- CMake
- PowerShell Core
- Visual C++ Redistributables
- Windows SDK components

## Example Actions

Here are some example workflows that demonstrate how to use the Windows runner:

### Environment Testing

```yaml
name: Windows Runner Environment Test
on: 
  workflow_dispatch:  # Manual trigger
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  test-environment:
    runs-on: windows
    
    steps:
      - name: System Information
        run: |
          systeminfo | Select-String "OS Name", "OS Version", "System Type"
          Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
          Write-Host "Available RAM: $((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb)GB"
          
      - name: Test Visual Studio Environment
        run: |
          Write-Host "Visual Studio Installation:"
          Get-VSSetupInstance
          
          Write-Host "`nMSBuild Version:"
          msbuild -version
          
          Write-Host "`nInstalled Workloads:"
          (Get-VSSetupInstance | Select-VSSetupInstance -Product *).Packages | Select-Object -ExpandProperty "Id"
          
      - name: Test .NET Environment
        run: |
          Write-Host ".NET SDKs:"
          dotnet --list-sdks
          
          Write-Host "`n.NET Runtimes:"
          dotnet --list-runtimes
          
      - name: Test Unity Environment
        run: |
          $unityEditorPath = "C:/BuildTools/UnityEditor/2019.4.24f1/Editor/Unity.exe"
          if (Test-Path $unityEditorPath) {
              Write-Host "Unity Editor found at: $unityEditorPath"
              & $unityEditorPath -version
          } else {
              Write-Error "Unity Editor not found!"
          }
          
      - name: Test Node.js Environment
        run: |
          Write-Host "Node.js Version:"
          node --version
          
          Write-Host "`nnpm Version:"
          npm --version
          
          Write-Host "`nGlobal npm packages:"
          npm list -g --depth=0
          
      - name: Test Rust Environment
        run: |
          Write-Host "Rust Version:"
          rustc --version
          
          Write-Host "`nCargo Version:"
          cargo --version
          
          Write-Host "`nInstalled Components:"
          rustup component list --installed
          
      - name: Test Build Tools
        run: |
          Write-Host "Chocolatey Version:"
          choco --version
          
          Write-Host "`nGit Version:"
          git --version
          
          Write-Host "`nCMake Version:"
          cmake --version
          
          Write-Host "`nNinja Version:"
          ninja --version
          
      - name: Test Environment Variables
        run: |
          $envVars = @(
              'VSINSTALLPATH',
              'UNITY_EDITOR',
              'RUSTUP_HOME',
              'CARGO_HOME',
              'RUNNER_TEMP',
              'RUNNER_WORKSPACE'
          )
          
          foreach ($var in $envVars) {
              $value = [Environment]::GetEnvironmentVariable($var)
              Write-Host "${var}: $value"
          }
          
      - name: Test Disk Space
        run: |
          Get-Volume | Where-Object { $_.DriveLetter } | 
          Format-Table -AutoSize DriveLetter, FileSystemLabel, 
          @{Name='Size(GB)';Expression={[math]::Round($_.Size/1GB,2)}}, 
          @{Name='FreeSpace(GB)';Expression={[math]::Round($_.SizeRemaining/1GB,2)}}
          
      - name: Test ImageHelpers Module
        run: |
          # Import ImageHelpers module
          $modulePath = Join-Path $env:RUNNER_WORKSPACE "scripts\helpers\ImageHelpers.psm1"
          Import-Module $modulePath -Force
          
          Write-Host "Testing Install-Binary function..."
          try {
              # Test downloading and installing a small utility
              Install-Binary -Url "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe" `
                           -Type "EXE" `
                           -InstallArgs @("/VERYSILENT") `
                           -ExpectedSHA256Sum "a51d36968dcbdeabb3142c6f5cf9b401a65dc3a095f3144bd0c118d5bb192753"
              Write-Host "Install-Binary test passed"
          } catch {
              Write-Error "Install-Binary test failed: $_"
          }
          
          Write-Host "`nTesting Unity installation functions..."
          try {
              $unityVersion = "2019.4.24f1"
              $changeSet = Get-UnityChangeSet -Version $unityVersion
              if ($changeSet) {
                  Write-Host "Get-UnityChangeSet test passed for version $unityVersion (ChangeSet: $changeSet)"
              } else {
                  Write-Error "Get-UnityChangeSet test failed for version $unityVersion"
              }
              
              $editorPath = Get-UnityEditorPath -Version $unityVersion
              if ($editorPath) {
                  Write-Host "Get-UnityEditorPath test passed (Path: $editorPath)"
              } else {
                  Write-Error "Get-UnityEditorPath test failed"
              }
          } catch {
              Write-Error "Unity installation functions test failed: $_"
          }
          
          Write-Host "`nTesting Visual Studio functions..."
          try {
              $vsInstance = Get-VisualStudioBuildToolsInstances -Version "17"
              if ($vsInstance) {
                  Write-Host "Get-VisualStudioBuildToolsInstances test passed"
                  Write-Host "Installation Path: $($vsInstance.InstallationPath)"
                  
                  $packageIds = Get-VisualStudioInstancePackageIds -Instance $vsInstance -PackageType "Workload"
                  Write-Host "Installed Workloads: $($packageIds -join ', ')"
              } else {
                  Write-Error "Get-VisualStudioBuildToolsInstances test failed"
              }
          } catch {
              Write-Error "Visual Studio functions test failed: $_"
          }
          
          Write-Host "`nTesting helper functions..."
          try {
              # Test download with retry
              $testFile = Join-Path $env:TEMP "test.txt"
              Invoke-DownloadWithRetry -Url "https://raw.githubusercontent.com/actions/runner-images/main/README.md" `
                                     -Path $testFile
              if (Test-Path $testFile) {
                  Write-Host "Invoke-DownloadWithRetry test passed"
                  Remove-Item $testFile -Force
              }
              
              # Test environment update
              Update-Environment
              Write-Host "Update-Environment test passed"
              
              # Test script block retry
              $result = Invoke-ScriptBlockWithRetry -ScriptBlock { 
                  return "Test successful" 
              } -RetryCount 3
              if ($result -eq "Test successful") {
                  Write-Host "Invoke-ScriptBlockWithRetry test passed"
              }
          } catch {
              Write-Error "Helper functions test failed: $_"
          }
          
      - name: Generate Environment Report
        run: |
          $report = @{
              Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
              OS = (Get-CimInstance Win32_OperatingSystem).Caption
              PowerShell = $PSVersionTable.PSVersion.ToString()
              DotNet = (dotnet --version)
              Node = (node --version)
              Rust = (rustc --version)
              Unity = if (Test-Path "C:/BuildTools/UnityEditor/2019.4.24f1/Editor/Unity.exe") { "2019.4.24f1" } else { "Not Found" }
              VisualStudio = (Get-VSSetupInstance | ForEach-Object { $_.DisplayName } | Join-String -Separator ", ")
          }
          
          $report | ConvertTo-Json | Out-File environment-report.json
          
      - name: Upload Environment Report
        uses: actions/upload-artifact@v3
        with:
          name: environment-report
          path: environment-report.json
```

This workflow will:
1. Check system information and available resources
2. Verify Visual Studio installation and components
3. Test .NET environment and available SDKs
4. Verify Unity Editor installation
5. Check Node.js and npm configuration
6. Test Rust toolchain and components
7. Verify build tools installation
8. Check environment variables
9. Test available disk space
10. Test ImageHelpers module
11. Generate and upload a JSON report of the environment

You can run this workflow:
- Manually through the Actions tab
- Automatically on a weekly schedule
- As part of your CI/CD pipeline to verify the environment before builds

The environment report artifact will help you:
- Track changes in the runner environment over time
- Debug issues related to tool versions
- Ensure all required components are properly installed
- Document the exact state of the runner for reproducibility

### .NET Build and Test

```yaml
name: .NET Build and Test
on: [push, pull_request]

jobs:
  build:
    runs-on: windows
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '7.0.x'
          
      - name: Restore dependencies
        run: dotnet restore
        
      - name: Build
        run: dotnet build --no-restore --configuration Release
        
      - name: Test
        run: dotnet test --no-build --configuration Release

      - name: Publish
        run: dotnet publish --no-build --configuration Release --output ./publish
        
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: webapp
          path: ./publish
```

### Unity Build

```yaml
name: Unity Build
on: [push, pull_request]

jobs:
  build:
    runs-on: windows
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Cache Library folder
        uses: actions/cache@v3
        with:
          path: Library
          key: Library-${{ hashFiles('Assets/**', 'Packages/**', 'ProjectSettings/**') }}
          restore-keys: |
            Library-
            
      - name: Build Unity Project
        env:
          UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
          UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}
          UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}
        run: |
          # Unity is pre-installed in the runner
          & "C:/BuildTools/UnityEditor/2019.4.24f1/Editor/Unity.exe" `
            -quit `
            -batchmode `
            -nographics `
            -silent-crashes `
            -logFile `
            -projectPath . `
            -executeMethod BuildScript.Build `
            -buildTarget StandaloneWindows64 `
            -buildPath ./Build/Windows
            
      - name: Upload build
        uses: actions/upload-artifact@v3
        with:
          name: WindowsBuild
          path: Build/Windows
```

### Node.js with Native Modules

```yaml
name: Node.js Native Build
on: [push, pull_request]

jobs:
  build:
    runs-on: windows
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18.x'
          
      - name: Install dependencies
        run: |
          npm config set msvs_version 2022
          npm install --build-from-source
          
      - name: Build
        run: npm run build
        
      - name: Test
        run: npm test
        
      - name: Package
        run: npm pack
        
      - name: Upload package
        uses: actions/upload-artifact@v3
        with:
          name: package
          path: "*.tgz"
```

### Rust Project

```yaml
name: Rust Build
on: [push, pull_request]

jobs:
  build:
    runs-on: windows
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install latest rust toolchain
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          default: true
          override: true
          
      - name: Build
        uses: actions-rs/cargo@v1
        with:
          command: build
          args: --release --all-features
          
      - name: Run tests
        uses: actions-rs/cargo@v1
        with:
          command: test
          args: --all-features
          
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: windows-release
          path: target/release/*.exe
```

### Visual Studio C++ Project

```yaml
name: VS C++ Build
on: [push, pull_request]

jobs:
  build:
    runs-on: windows
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Add MSBuild to PATH
        uses: microsoft/setup-msbuild@v1
        
      - name: Build Solution
        run: |
          msbuild /p:Configuration=Release /p:Platform=x64 YourSolution.sln
          
      - name: Run Tests
        run: |
          cd x64/Release
          ./YourTests.exe
          
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: binaries
          path: x64/Release/*.exe
```

## Environment Variables

The following environment variables can be used in your workflows:

- `UNITY_EDITOR`: Path to Unity Editor (e.g., `C:/BuildTools/UnityEditor/2019.4.24f1/Editor/Unity.exe`)
- `VSINSTALLPATH`: Path to Visual Studio installation
- `RUSTUP_HOME`: Rust installation directory
- `CARGO_HOME`: Cargo home directory
- `NODE_PATH`: Node.js installation directory

## Notes on Windows Paths

When working with paths in Windows runners:

1. Use forward slashes (`/`) or escaped backslashes (`\\`) in YAML
2. Use PowerShell style paths in PowerShell scripts
3. Environment variables use Windows style paths with backslashes

Example path usage:
```yaml
- name: Example Path Usage
  run: |
    # PowerShell style
    $unityPath = "C:\BuildTools\UnityEditor"
    
    # YAML style
    path: C:/BuildTools/UnityEditor
    # or
    path: C:\\BuildTools\\UnityEditor
```

## Commands

### Build and Run

```powershell
# Build with specific version
docker compose build --build-arg GITEA_RUNNER_VERSION=0.2.11

# Build with specific version and tag
docker compose build \
    --build-arg GITEA_RUNNER_VERSION=0.2.11 \
    --build-arg WINDOWS_IMAGE=your-registry/your-custom-windows-image:1.0.0 \
    gitea-runner

# Start runner
docker compose up -d

# View logs
docker compose logs -f

# Stop runner
docker compose down
```

### Maintenance

```powershell
# View runner status
docker compose ps

# View detailed logs
docker compose logs -f --tail=100

# Restart runner
docker compose restart

# Update to latest version
docker compose pull
docker compose up -d
```

## Troubleshooting

### Common Issues

1. Build fails:
   - Ensure Docker Desktop is set to Windows containers
   - Try rebuilding without cache: `docker compose build --no-cache`
   - Check build logs for specific errors

2. Runner fails to start:
   - Verify environment variables in `.env` or `docker-compose.yaml`
   - Check Gitea instance URL is accessible
   - Ensure registration token is valid
   - View logs: `docker compose logs -f`

3. Runner registration fails:
   - Check network connectivity to Gitea instance
   - Verify registration token hasn't expired
   - Check for any proxy or firewall issues

### Logs

View runner logs:
```powershell
# Follow logs
docker compose logs -f

# View last N lines
docker compose logs --tail=100

# View logs for specific time
docker compose logs --since 30m

```

## References

- [Visual Studio Build Tools Documentation](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio)
- [Unity CI Docker Images](https://hub.docker.com/r/unityci/hub/tags)
- [Gitea Actions Documentation](https://docs.gitea.io/en-us/actions/)
