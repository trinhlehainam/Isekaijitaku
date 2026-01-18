---
aliases:
  - "Unity UWP Build Action"
tags:
  - manifest
---

# Unity UWP Build Action

This action is designed to build Unity UWP (Universal Windows Platform) projects using GameCI and MSBuild.

## Prerequisites

1. Unity License
   - Personal license requires Unity account credentials
   - Professional license requires a license file
2. Unity project with UWP build support
3. Unity version compatible with GameCI (2019.4.x or later recommended)
4. Visual Studio Build Tools with UWP components:
   - Universal Windows Platform build tools
   - UWP VC build tools
   - UWP VC v142 build tools
   - Windows 11 SDK (10.0.22621.0)

## Environment Variables

### Required Secrets
- `UNITY_LICENSE`: Your Unity license
- `UNITY_EMAIL`: Your Unity account email (for activation)
- `UNITY_PASSWORD`: Your Unity account password (for activation)
- `CERT_BASE64_ENCODED`: Base64-encoded signing certificate for UWP package
- `CERT_PASSWORD`: Password for the signing certificate

### Workflow Environment Variables

#### Global Variables
These variables are defined at the workflow level:
```yaml
env:
  APP_NAME: TestApp
  CERT_PATH: cert.pfx
```

#### Step-Specific Variables
Due to GitHub Actions limitations, variables that depend on other environment variables should be defined within the specific steps that use them:

```yaml
- name: Build UWP App
  env:
    SOLUTION_PATH: build/${{ env.APP_NAME }}.sln
    PACKAGE_PATH: build/AppPackages/${{ env.APP_NAME }}
    CERT_PASSWORD: ${{ secrets.CERT_PASSWORD }}
  run: |
    msbuild $env:SOLUTION_PATH ...
```

> **Note**: GitHub Actions does not support using one environment variable to define another directly within the same `env` block. Instead:
> - Define basic variables at the workflow level
> - Create dependent variables within specific steps
> - Use step outputs for values that need to be shared between steps
> - Use shell commands within steps to combine variables

For example, instead of:
```yaml
# This won't work
env:
  BASE_PATH: build
  FULL_PATH: ${{ env.BASE_PATH }}/output  # ❌ Cannot reference env.BASE_PATH here
```

Use:
```yaml
# This is the correct approach
env:
  BASE_PATH: build  # Define basic variable

steps:
  - name: Your Step
    env:
      FULL_PATH: ${{ env.BASE_PATH }}/output  # ✅ Define dependent variable in step
    run: echo $FULL_PATH
```

## Matrix Strategy

The workflow uses a matrix strategy to build multiple configurations:

1. Unity Projects:
   ```yaml
   unityProjectPath:
     - test-project
   ```

2. Unity Versions:
   ```yaml
   unityVersions:
     - 2019.4.31f1
   ```

3. Target Platforms:
   ```yaml
   targetPlatforms:
     - WSAPlayer  # Build for UWP
   ```

4. Build Platforms:
   - x86
   - x64
   - ARM
   - ARM64

5. Configurations:
   - Debug
   - Release

## Workflow Description

The workflow performs the following steps:

1. Checks out the repository with LFS support
2. Sets up caching for Unity Library folder (per project)
3. Runs Unity tests (if any)
4. Builds the Unity project for UWP using GameCI builder:
   ```yaml
   with:
     buildName: UWPBuild
     projectPath: ${{ matrix.unityProjectPath }}
     unityVersion: ${{ matrix.unityVersions }}
     targetPlatform: ${{ matrix.targetPlatforms }}
     customParameters: -profile SomeProfile -someBoolean -someValue exampleValue
   ```
5. Sets up MSBuild environment:
   - Installs MSBuild tools
   - Configures Windows SDK
   - Sets up .NET SDK
6. Processes signing certificate (for non-PR builds)
7. Builds UWP solution with MSBuild:
   - Creates MSIX package
   - Configures for Store submission
8. Uploads build artifacts

## Build Output

The workflow generates:
- MSIX packages for store submission
- Separate builds for each platform (x86, x64, ARM, ARM64)
- Debug and Release configurations
- Build artifacts are uploaded with the naming format:
  `MSIX-{project}-{platform}-{configuration}`

## Troubleshooting

Common issues:
1. Unity Build Issues
   - Verify Unity version compatibility
   - Check Unity project settings
   - Ensure UWP build support is installed
   - Review GameCI builder logs

2. MSBuild Errors
   - Verify Visual Studio Build Tools installation
   - Check UWP components installation
   - Validate Windows SDK version
   - Review MSBuild logs

3. Certificate Issues
   - Ensure certificate is properly encoded in BASE64
   - Verify certificate password
   - Check certificate expiration
   - Confirm certificate is installed correctly

4. Environment Variables
   - Verify all required secrets are set
   - Check environment variable references
   - Validate paths in environment variables

## References

### Unity and GameCI
- [GameCI Documentation](https://game.ci/docs)
- [Unity Builder Action](https://github.com/game-ci/unity-builder)
- [Unity Test Runner Action](https://github.com/game-ci/unity-test-runner)
- [Unity Build Support Modules](https://docs.unity3d.com/Manual/BuildSettings.html)
- [Unity UWP Build Settings](https://docs.unity3d.com/Manual/windowsstore-builds.html)

### GitHub Actions
- [GitHub Actions Environment Variables](https://docs.github.com/en/actions/learn-github-actions/variables)
- [GitHub Actions Matrix Strategy](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs)
- [GitHub Actions Caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [GitHub Actions Artifacts](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)

### Visual Studio and UWP
- [Visual Studio Build Tools Workload IDs](https://github.com/MicrosoftDocs/visualstudio-docs/blob/main/docs/install/includes/vs-2022/workload-component-id-vs-build-tools.md)
- [MSBuild Command-Line Reference](https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-command-line-reference)
- [UWP App Packaging](https://learn.microsoft.com/en-us/windows/uwp/packaging/)
- [Windows SDK Archive](https://developer.microsoft.com/en-us/windows/downloads/sdk-archive/)

### Code Signing
- [UWP Code Signing](https://learn.microsoft.com/en-us/windows/uwp/packaging/create-certificate-package-signing)
- [Working with Base64 Certificates](https://learn.microsoft.com/en-us/powershell/module/pkiclient/export-certificate)
- [MSIX Packaging Tool](https://learn.microsoft.com/en-us/windows/msix/packaging-tool/tool-overview)

### Tools Used
- [actions/checkout](https://github.com/actions/checkout)
- [actions/cache](https://github.com/actions/cache)
- [microsoft/setup-msbuild](https://github.com/microsoft/setup-msbuild)
- [microsoft/setup-windowssdk](https://github.com/microsoft/setup-windowssdk)
- [actions/setup-dotnet](https://github.com/actions/setup-dotnet)
- [actions/upload-artifact](https://github.com/actions/upload-artifact)
