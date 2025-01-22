# Unity UWP Build Action

This action is designed to build Unity UWP (Universal Windows Platform) projects using GameCI and MSBuild.

## Prerequisites

1. Unity License
   - Personal license requires Unity account credentials
   - Professional license requires a license file
2. Unity project with UWP build support
3. Unity version compatible with GameCI (2019.4.x or later recommended)
4. Windows SDK 10.0.22621.0
5. .NET SDK 7.0.x
6. Code signing certificate (for store submissions)

## Environment Variables Required

- `UNITY_LICENSE`: Your Unity license
- `UNITY_EMAIL`: Your Unity account email (for activation)
- `UNITY_PASSWORD`: Your Unity account password (for activation)
- `BASE64_ENCODED_PFX`: Base64-encoded signing certificate for UWP package
- `CERTIFICATE_PASSWORD`: Password for the signing certificate

These should be set as repository secrets.

## Matrix Strategy

The workflow uses a matrix strategy to build multiple configurations:

1. Unity Projects:
   - Configure multiple Unity project paths in the matrix
   - Each project is built separately

2. Platforms:
   - x86 (Win32)
   - x64
   - ARM64

3. Configurations:
   - Debug
   - Release

## Workflow Description

The workflow performs the following steps:

1. Checks out the repository with LFS support
2. Sets up caching for Unity Library folder (per project)
3. Runs Unity tests (if any)
4. Builds the Unity project for UWP
5. Sets up MSBuild environment:
   - Installs MSBuild tools
   - Configures Windows SDK
   - Sets up .NET SDK
6. Processes signing certificate (for non-PR builds)
7. Builds UWP solution with MSBuild:
   - Creates MSIX package
   - Configures for Store submission
8. Uploads build artifacts

## Usage

1. Add the workflow file to `.github/workflows/` in your repository
2. Configure the required secrets in your repository settings
3. Update the matrix configuration with your Unity project paths:
   ```yaml
   strategy:
     matrix:
       unity_project: ['MyGame1/uwp', 'MyGame2/uwp']
   ```
4. Push changes to trigger the workflow

## Build Output

The workflow generates:
- MSIX packages for store submission
- Separate builds for each platform (x86, x64, ARM64)
- Debug and Release configurations
- Build artifacts are uploaded with the naming format:
  `MSIX-{project}-{platform}-{configuration}`

## Troubleshooting

Common issues:
1. License activation failures
   - Verify credentials are correct
   - Ensure license is valid for the Unity version
2. Build failures
   - Check Unity project settings
   - Verify UWP build support is installed
   - Check build logs for specific errors
3. MSBuild errors
   - Verify Windows SDK installation
   - Check certificate configuration
   - Validate UWP project settings
4. Package signing issues
   - Ensure certificate is properly encoded
   - Verify certificate password
   - Check certificate expiration
