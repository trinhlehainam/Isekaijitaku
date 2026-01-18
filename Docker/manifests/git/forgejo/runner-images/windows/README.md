---
aliases:
  - "Windows Runner Images for Gitea Actions"
tags:
  - manifest
---

# Windows Runner Images for Gitea Actions

This directory contains the source for the Windows container images used by Gitea Actions runners. These images are based on the architecture and implementation of [GitHub Actions Runner Images](https://github.com/actions/runner-images).

## Base Image

- Windows Server Core LTSC 2022 (`mcr.microsoft.com/windows/servercore:ltsc2022`)

## Installed Software

The following software is installed in the Windows image:

### Development Tools

- Git
- Node.js LTS
- Python with common prerequisites
- Rust
- Visual Studio Build Tools
- .NET SDK
- PowerShell Core

### Build Tools

- Windows SDK
- Visual C++ Build Tools
- CMake
- Ninja
- MSYS2
- Windows Performance Toolkit

## Directory Structure

```
windows/
├── Dockerfile              # Container definition
├── Setup.ps1              # Main setup script
├── README.md              # This documentation
├── build/                 # Build tool installation scripts
│   ├── Install-Git.ps1
│   ├── Install-NodeJS.ps1
│   ├── Install-OptionalBuildTools.ps1
│   ├── Install-PrerequisiteBuildTools.ps1
│   ├── Install-PythonPrerequisites.ps1
│   └── Install-Rust.ps1
└── helpers/               # Helper functions and modules
    ├── ImageHelpers.psd1
    ├── ImageHelpers.psm1
    └── InstallHelpers.ps1
```

## Building the Image

```powershell
# Build the base image
docker build -t forgejo-runner-windows-tools -f Dockerfile .
```

## Installation Process

The installation process follows these steps:

1. **Base Setup** (`Setup.ps1`)
   - Configures PowerShell execution policy
   - Sets up environment variables
   - Initializes logging

2. **Prerequisite Tools** (`Install-PrerequisiteBuildTools.ps1`)
   - Visual Studio Build Tools
   - Windows SDK
   - .NET SDK

3. **Development Tools**
   - Git (`Install-Git.ps1`)
   - Node.js (`Install-NodeJS.ps1`)
   - Python prerequisites (`Install-PythonPrerequisites.ps1`)
   - Rust (`Install-Rust.ps1`)

4. **Optional Tools** (`Install-OptionalBuildTools.ps1`)
   - Additional build tools and SDKs
   - Language-specific tools

## Customization

The image can be customized by:

1. Modifying installation scripts in the `build/` directory
2. Adding new installation scripts
3. Updating `Setup.ps1` to include/exclude tools

## References

### Official Documentation

- [Windows Server Core Base Images](https://hub.docker.com/_/microsoft-windows-servercore)
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
- [Windows SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/)
- [PowerShell Modules](https://learn.microsoft.com/en-us/powershell/scripting/developer/module/understanding-a-windows-powershell-module)

### GitHub Actions References

- [Runner Images](https://github.com/actions/runner-images)
- [Virtual Environments](https://github.com/actions/virtual-environments)
- [Runner Architecture](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)

### Related Projects

- [act_runner](https://gitea.com/gitea/act_runner)
- [actions/runner](https://github.com/actions/runner)

## Notes

- The image is optimized for CI/CD scenarios
- All tools are installed in their default locations
- The installation process is designed to be reproducible and maintainable
- Regular updates are recommended to keep tools and dependencies current