---
aliases:
  - "Windows Development Docker Container"
tags:
  - manifest
---

# Windows Development Docker Container

This repository contains Dockerfile and scripts for creating Windows containers with Visual Studio Build Tools and necessary components for Unity and Unreal Engine development.

## Features

- Visual Studio Build Tools 2022 with all necessary components
- Collected and optimized DLL files for game engine builds
- Windows SDK and development tools
- Build system tools (CMake, Ninja)
- Source control (Git)
- Python for build scripts

## Prerequisites

- Windows 10/11 Pro or Enterprise, or Windows Server 2019/2022
- Docker Desktop for Windows
- Hyper-V enabled
- At least 50GB of free disk space

## Quick Start

1. Switch to Windows containers in Docker Desktop
2. Build the image:
```powershell
docker build -t game-dev-env .
```

3. Build with custom versions:
```powershell
docker build -t game-dev-env `
    --build-arg VS_VERSION=2022 `
    --build-arg VS_BUILD_TOOLS_VERSION=17.8.3 `
    --build-arg WINDOWS_SDK_VERSION=19041 `
    .
```

4. Run the container:
```powershell
docker run -it game-dev-env
```

## Container Structure

- `/BuildTools/DLLs`: Contains optimized collection of necessary DLLs
- `/tools/msvc`: Symbolic link to MSVC tools
- `/tools/sdk`: Symbolic link to Windows SDK
- `/workspace`: Default working directory

## Documentation

- [Detailed Setup Guide](./SETUP_GUIDE.md)
- [Build Prerequisites Script](./Install-BuildPrerequisites.ps1)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
