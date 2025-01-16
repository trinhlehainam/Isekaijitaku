# Detailed Setup Guide for Game Development Container

This guide provides detailed instructions for setting up and customizing the Windows container for Unity and Unreal Engine development.

## System Requirements

### Host Machine Requirements
- Windows 10/11 Pro or Enterprise, or Windows Server 2019/2022
- Docker Desktop for Windows
- Hyper-V enabled
- At least 50GB free disk space
- 16GB RAM recommended
- Virtualization enabled in BIOS

### Docker Configuration
1. Install Docker Desktop for Windows
2. Switch to Windows containers:
   - Right-click Docker Desktop icon in system tray
   - Select "Switch to Windows containers..."
3. Configure resource limits in Docker Desktop:
   - Memory: At least 8GB
   - Disk space: At least 50GB

## Building the Container

### Basic Build
```powershell
docker build -t game-dev-env .
```

### Build with Custom Options
```powershell
docker build -t game-dev-env `
    --build-arg VS_VERSION=2022 `
    --build-arg VS_BUILD_TOOLS_VERSION=17.8.3 `
    --build-arg WINDOWS_SDK_VERSION=19041 `
    .
```

## Container Components

### Visual Studio Build Tools
The container includes essential components for both Unity and Unreal Engine development:

#### Core Components
- MSBuild Tools
- C++ Build Tools
- Windows SDK
- VC++ x86/x64 and ARM64 Build Tools
- ATL/MFC Support

### DLL Management
The container includes an optimized collection of DLLs required for game engine builds:

#### DLL Location
- All necessary DLLs are collected in `C:\BuildTools\DLLs`
- Duplicates are automatically removed, keeping only the latest versions
- Symbolic links are created for easy access

#### Included DLL Categories
- MSVC Runtime DLLs
- Universal C Runtime DLLs
- Windows SDK DLLs

### Development Tools
- CMake for build configuration
- Ninja build system
- Git for version control
- Python for build scripts

## Customizing the Build

### Adding Visual Studio Components

1. Find component IDs from [Microsoft's documentation](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools)
2. Add components to `Install-BuildPrerequisites.ps1`:

```powershell
$vsComponents = @(
    "Microsoft.VisualStudio.Component.YourComponentId",
    # Add more components here
)
```

### Managing DLLs

The `Install-BuildPrerequisites.ps1` script automatically:
1. Collects necessary DLLs from Visual Studio and Windows SDK
2. Removes duplicate versions
3. Places them in an accessible location

## Common Issues and Solutions

### Build Issues
- Ensure Windows SDK version matches your engine requirements
- Verify all required DLLs are present in `C:\BuildTools\DLLs`
- Check Visual Studio Build Tools installation is complete

### Container Size Management
- Use `--squash` flag during build (experimental feature)
- Regular cleanup of temporary files
- Use multi-stage builds when possible

### Visual Studio Installation Issues
- Ensure enough disk space
- Check Windows Update is not running
- Verify network connectivity
- Use `--debug` flag for verbose logging

## Best Practices

1. **DLL Management**
   - Keep DLL collection updated
   - Verify DLL versions match engine requirements
   - Use symbolic links for easy access

2. **Build Configuration**
   - Use appropriate Windows SDK version
   - Include all necessary Visual Studio components
   - Maintain proper DLL versions

3. **Performance**
   - Use build cache effectively
   - Optimize layer ordering
   - Use appropriate base image

## References

- [Visual Studio Build Tools Documentation](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio)
- [Windows SDK Documentation](https://learn.microsoft.com/en-us/windows/win32/windows-sdk)
- [Docker Windows Containers](https://docs.docker.com/desktop/windows/)
