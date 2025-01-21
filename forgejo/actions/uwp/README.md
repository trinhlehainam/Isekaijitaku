# UWP GitHub Actions Workflows

This directory contains GitHub Actions workflows for building and deploying Universal Windows Platform (UWP) applications.

## Workflows

### 1. Continuous Integration (ci.yml)

The CI workflow runs on every push to main branch and pull requests. It:
- Builds the UWP app for multiple platforms (x86, x64, ARM64)
- Supports both Debug and Release configurations
- Signs the package (if certificate is provided)
- Uploads build artifacts

Required secrets:
- `BASE64_ENCODED_PFX`: Base64-encoded signing certificate
- `CERTIFICATE_PASSWORD`: Password for the signing certificate

### 2. Continuous Deployment (cd.yml)

The CD workflow runs when a version tag (v*.*.*)is pushed. It consists of two jobs:

#### Build Job
- Builds separate MSIX packages for each platform (x86, x64, ARM64)
- Updates version in the app manifest
- Signs each package
- Uploads platform-specific artifacts

#### Release Job
- Downloads all platform artifacts
- Creates an MSIX bundle containing all platform packages
- Creates a GitHub release
- Uploads the bundle to the release

Required secrets:
- `BASE64_ENCODED_PFX`: Base64-encoded signing certificate
- `CERTIFICATE_PASSWORD`: Password for the signing certificate
- `GITHUB_TOKEN`: Automatically provided by GitHub

## Setup Instructions

### 1. Prepare Certificate
You have two options for creating a signing certificate:

#### Option 1: Create a new self-signed certificate
```powershell
# Create a new self-signed certificate
New-SelfSignedCertificate -Type Custom `
    -Subject "CN=YourCompanyName" `
    -KeyUsage DigitalSignature `
    -FriendlyName "Your App Signing Cert" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
    -NotAfter (Get-Date).AddYears(5)

# Export the certificate with private key to PFX
$password = ConvertTo-SecureString -String "YourPassword" -Force -AsPlainText
Export-PfxCertificate -Cert "Cert:\CurrentUser\My\<Certificate-Thumbprint>" `
    -FilePath ".\YourApp_Signing.pfx" `
    -Password $password
```

#### Option 2: Use an existing PFX certificate
If you already have a PFX certificate, you can use it directly.

### 2. Convert PFX to Base64
Convert your PFX file to base64 format using PowerShell:

```powershell
# Convert PFX to Base64
$pfxPath = ".\YourApp_Signing.pfx"
$base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($pfxPath))
$base64 | Set-Content "certificate_base64.txt"
```

### 3. Add Secrets to Forgejo/Gitea Repository

1. Navigate to your repository's settings
2. Go to "Secrets" section
3. Add the following secrets:
   - Name: `BASE64_ENCODED_PFX`
     - Value: The content of `certificate_base64.txt`
   - Name: `CERTIFICATE_PASSWORD`
     - Value: Your PFX certificate password

Note: Secret names in Forgejo/Gitea:
- Must contain only alphanumeric characters or underscores
- Must not start with numbers
- Must not start with `GITHUB_` or `GITEA_` prefix
- Are case-insensitive
- Must be unique at their level (repository/organization)

### 4. Configure Workflow Files

1. Place these workflow files in your `.forgejo/workflows` directory
2. Update the following variables in both workflows:
   - `Solution_Path`
   - `UWP_Project_Path`
   - `UWP_Project_Directory`
   - Asset paths in the CD workflow

## Usage

- For CI: Push to main or create a pull request
- For CD: Push a tag in format `v*.*.*` (e.g., v1.0.0)

## Matrix Build Strategy

Both workflows use matrix strategy to build packages for multiple platforms:
- x86 (32-bit)
- x64 (64-bit)
- ARM64 (ARM 64-bit)

This ensures that your app can run on all supported Windows 10/11 devices.

## Security Notes

1. Never commit the PFX file or its password to the repository
2. Always use repository secrets for sensitive data
3. The PFX file is decoded only during the build process and is immediately removed after signing
4. Certificate files are automatically cleaned up after each workflow run
5. Access to secrets is limited to workflow runs and is not available to pull requests from forks

## References

### Official Documentation
- [Forgejo Actions Documentation](https://forgejo.org/docs/v1.20/user/actions/)
- [Forgejo Secrets Management](https://docs.gitea.com/usage/secrets)
- [Windows App Certification Kit](https://learn.microsoft.com/en-us/windows/uwp/debug-test-perf/windows-app-certification-kit)
- [UWP App Packaging](https://learn.microsoft.com/en-us/windows/uwp/packaging/packaging-uwp-apps)

### Certificate Management
- [Windows Code Signing Best Practices](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/authenticode-signing-of-windows-applications)
- [PowerShell Certificate Commands](https://learn.microsoft.com/en-us/powershell/module/pki/new-selfsignedcertificate)
- [Working with Certificates in PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/samples/working-with-certificates)

### CI/CD Pipeline
- [Forgejo Actions Command Line](https://docs.gitea.com/administration/command-line#generate)
- [MSBuild Command Line Reference](https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-command-line-reference)
- [MSIX Packaging Tool](https://learn.microsoft.com/en-us/windows/msix/packaging-tool/tool-overview)
- [Automated UWP App Packaging](https://github.com/MicrosoftDocs/windows-dev-docs/blob/docs/uwp/packaging/auto-build-package-uwp-apps.md)
- [GitHub Actions for Desktop Apps](https://github.com/microsoft/github-actions-for-desktop-apps#workflows)

### Security
- [Forgejo Actions Security Guide](https://forgejo.org/docs/v1.20/user/actions/#secrets)
- [Secure Development and Deployment](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-compliance-toolkit-10)
- [Best Practices for UWP App Security](https://learn.microsoft.com/en-us/windows/uwp/security/security-best-practices)

### Tools and Utilities
- [Windows SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/)
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
- [SignTool Documentation](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool)