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
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes($pfxPath)) | Set-Content "pfx_cert_base64.txt"
```

### 3. Add Secrets to Forgejo/Gitea Repository

1. Navigate to your repository's settings
2. Go to "Secrets" section
3. Add the following secrets:
   - Name: `BASE64_ENCODED_PFX`
     - Value: The content of `pfx_cert_base64.txt`
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

## Modifying Package.appxmanifest

You can use PowerShell to programmatically modify the Package.appxmanifest file. Here are common scenarios and their implementations:

### Loading the Manifest

There are two ways to load the manifest file:

```powershell
# Method 1: Simple and concise
[xml]$manifest = Get-Content "\Path\To\Package.appxmanifest"

# Method 2: Using XmlDocument (provides more control over loading options)
$manifest = [System.Xml.XmlDocument]::new()
$manifest.Load("\Path\To\Package.appxmanifest")
```

### Node Manipulation

#### Creating Elements With and Without Namespaces

```powershell
[xml]$manifest = Get-Content "\Path\To\Package.appxmanifest"

# Create element without xmlns="" attribute
$noXmlnsElement = $manifest.CreateElement("Extensions", $manifest.DocumentElement.NamespaceURI)

# Create element with namespace prefix
$nsUri = $manifest.DocumentElement.GetNamespaceOfPrefix('uap')
$withNamespaceElement = $manifest.CreateElement("uap", "Extension", $nsUri)
```

#### Checking Existing Nodes

Before adding new nodes, it's essential to check if they already exist:

```powershell
[xml]$manifest = Get-Content "\Path\To\Package.appxmanifest"

# Check if a Capability exists
$uapNs = $manifest.DocumentElement.GetNamespaceOfPrefix('uap')
$capabilities = $manifest.Package.Capabilities
$hasDocumentsLibrary = $capabilities.ChildNodes | 
    Where-Object { ($_.Name -eq "Capability") -and ($_.GetAttribute("Name") -eq "documentsLibrary") }

if (-not $hasDocumentsLibrary) {
    # Create and append new capability
    $newCapability = $manifest.CreateElement("uap", "Capability", $uapNs)
    $newCapability.SetAttribute("Name", "documentsLibrary")
    [void]$capabilities.AppendChild($newCapability)
}
```

#### Controlling Node Position

You can insert nodes at specific positions instead of appending at the end:

```powershell
[xml]$manifest = Get-Content "\Path\To\Package.appxmanifest"

# Get the parent node
$capabilities = $manifest.Package.Capabilities

# Find reference node (e.g., the picturesLibrary capability)
$refNode = $capabilities.ChildNodes | 
    Where-Object { 
      ($_.Prefix -eq "uap") -and ($_.LocalName -eq "Capability") -and
      ($_.GetAttribute("Name") -eq "picturesLibrary") 
    }

if ($refNode) {
    # Create new node
    $uapNs = $manifest.DocumentElement.GetNamespaceOfPrefix('uap')
    $newCapability = $manifest.CreateElement("uap", "Capability", $uapNs)
    $newCapability.SetAttribute("Name", "documentsLibrary")

    # Insert after the reference node
    [void]$capabilities.InsertAfter($newCapability, $refNode)
    
    # Or insert before the reference node
    # [void]$capabilities.InsertBefore($newCapability, $refNode)
}
```

### Adding Capabilities

To add a new capability (e.g., documentsLibrary):

```powershell
# Load the manifest
[xml]$manifest = Get-Content "\Path\To\Package.appxmanifest"

# Get the namespace URI for 'uap'
$nsUri = $manifest.DocumentElement.GetNamespaceOfPrefix('uap')

# Check if capability already exists
$capabilities = $manifest.Package.Capabilities
$existingCapability = $capabilities.ChildNodes | 
    Where-Object { 
      ($_.Prefix -eq "uap") -and ($_.LocalName -eq "Capability") -and
      ($_.GetAttribute("Name") -eq "documentsLibrary") 
    }

if (-not $existingCapability) {
    # Create new Capability element
    $newCapability = $manifest.CreateElement("uap", "Capability", $nsUri)
    $newCapability.SetAttribute("Name", "documentsLibrary")

    # Append to the Capabilities node
    [void]$capabilities.AppendChild($newCapability)
}

# Save the changes
$manifest.Save("\Path\To\Package.appxmanifest")
```

### Adding File Type Associations

To add file type associations to a specific application:

```powershell
# Load the manifest
[xml]$manifest = Get-Content "\Path\To\Package.appxmanifest"

# Find the specific application by EntryPoint
$application = $manifest.Package.Applications.ChildNodes | Where-Object { ($_.EntryPoint -eq "YourApp.App") }

if (-not $application) {
    Write-Error "Application not found"
    return
}

# Check if Extensions node exists
$extensions = $application.ChildNodes | Where-Object { $_.LocalName -eq "Extensions" }

# Create Extensions node if it doesn't exist
if (-not $extensions) {
    # Using parent's namespace to avoid xmlns="" attribute
    # https://stackoverflow.com/a/8676037
    $extensions = $manifest.CreateElement("Extensions", $manifest.DocumentElement.NamespaceURI)
    [void]$application.AppendChild($extensions)
}

# Check if file type association already exists
$hasFileTypeAssociation = $extensions.ChildNodes | Where-Object { 
    ($_.Prefix -eq "uap") -and ($_.LocalName -eq "Extension") -and
    ($_.GetAttribute("Category") -eq "windows.fileTypeAssociation")
}

if (-not $hasFileTypeAssociation) {
    # Get the namespace URI for 'uap'
    $nsUri = $manifest.DocumentElement.GetNamespaceOfPrefix('uap')

    # Create Extension structure
    $extension = $manifest.CreateElement("uap", "Extension", $nsUri)
    $extension.SetAttribute("Category", "windows.fileTypeAssociation")

    $fileTypeAssoc = $manifest.CreateElement("uap", "FileTypeAssociation", $nsUri)
    $fileTypeAssoc.SetAttribute("Name", "test")

    $supportedTypes = $manifest.CreateElement("uap", "SupportedFileTypes", $nsUri)
    $fileType = $manifest.CreateElement("uap", "FileType", $nsUri)
    $fileType.InnerText = ".txt"

    $displayName = $manifest.CreateElement("uap", "DisplayName", $nsUri)
    $displayName.InnerText = "test"

    # Build the XML structure
    $supportedTypes.AppendChild($fileType)
    $fileTypeAssoc.AppendChild($supportedTypes)
    $fileTypeAssoc.AppendChild($displayName)
    $extension.AppendChild($fileTypeAssoc)

    # Append to the Extensions node
    [void]$extensions.AppendChild($extension)
}

# Save the changes
$manifest.Save("\Path\To\Package.appxmanifest")
```

Key changes in this example:
1. Creates `Extensions` element using parent's namespace (`$manifest.DocumentElement.NamespaceURI`) to avoid xmlns="" attribute
2. The resulting XML will have a clean `<Extensions>` tag without any xmlns attribute
3. Finds specific application by `EntryPoint` attribute
4. Maintains proper node ordering within the Application element

### Working with Namespaces

Package.appxmanifest uses several predefined Microsoft schemas. Here's how to work with them:

#### Checking Available Namespaces

To view namespaces defined in the manifest:

```powershell
[xml]$manifest = Get-Content "\Path\To\Package.appxmanifest"

# List all namespace declarations
$manifest.DocumentElement.Attributes | Where-Object { $_.Prefix -eq "xmlns" } | 
    Format-Table Name, Value

# Get specific namespace URI
$nsUri = $manifest.DocumentElement.GetNamespaceOfPrefix('uap')
Write-Host "UAP Namespace: $nsUri"
```

Common namespace prefixes in Package.appxmanifest:
```xml
xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
xmlns:mp="http://schemas.microsoft.com/appx/2014/phone/manifest"
xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
xmlns:uap2="http://schemas.microsoft.com/appx/manifest/uap/windows10/2"
xmlns:uap3="http://schemas.microsoft.com/appx/manifest/uap/windows10/3"
xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
```

When creating new elements, make sure to use the correct namespace URI:

```powershell
# Get namespace URI for specific prefix
$uapNs = $manifest.DocumentElement.GetNamespaceOfPrefix('uap')
$rescapNs = $manifest.DocumentElement.GetNamespaceOfPrefix('rescap')

# Create elements with correct namespaces
$uapCapability = $manifest.CreateElement("uap", "Capability", $uapNs)
$rescapCapability = $manifest.CreateElement("rescap", "Capability", $rescapNs)
```

### Important Notes

1. Always backup your Package.appxmanifest file before making modifications
2. Make sure to use the correct namespace prefixes (uap, uap2, etc.) as defined in your manifest
3. The XML is case-sensitive, so make sure to match the exact casing of elements and attributes
4. The `[void]` operator is used to suppress output when appending nodes
5. Test the modified manifest thoroughly before deployment

## Modifying Visual Studio Project Settings

### Changing Platform Toolset

To change the platform toolset (e.g., to Visual Studio 2022), you can modify the project file using PowerShell:

```powershell
# Load the project settings file
[xml]$projectSettings = Get-Content "\Path\To\YourApp.vcxproj"

# Find all PropertyGroup elements
$propertyGroups = $projectSettings.Project.ChildNodes |
    Where-Object { $_.LocalName -eq "PropertyGroup" -and $_.Label -eq "Configuration" } 
    
if (-not $propertyGroups) {
    Write-Host "No PropertyGroup elements found."
    return
}

# Find and update PlatformToolset
$propertyGroups.ChildNodes |
  Where-Object { $_.LocalName -eq "PlatformToolset" } |
  ForEach-Object { $_.InnerText = "v143" }

# Save changes
$projectSettings.Save("\Path\To\YourApp.vcxproj")
```

You can also target specific configurations:

```powershell
# Load the project settings file
[xml]$projectSettings = Get-Content "\Path\To\YourApp.vcxproj"

# Find ItemGroup elements
$debugConfigs = $projectSettings.Project.ChildNodes |
    Where-Object { 
        $_.LocalName -eq "PropertyGroup" -and
        ($_.Condition -match "'Debug\|.*'") -and 
        ($_.PlatformToolset)
    }

# Save changes
$projectSettings.Save("\Path\To\YourApp.vcxproj")
```

Available Platform Toolset values:
- `v143` - Visual Studio 2022
- `v142` - Visual Studio 2019
- `v141` - Visual Studio 2017

Note: After modifying the project file, you need to reload the project in Visual Studio for changes to take effect.

References:
- [Visual Studio Platform Toolsets](https://learn.microsoft.com/en-us/cpp/build/how-to-modify-the-target-framework-and-platform-toolset)

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

### Package.appxmanifest Management
- [Package manifest schema reference](https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/appx-package-manifest)
- [App capability declarations](https://learn.microsoft.com/en-us/windows/uwp/packaging/app-capability-declarations)
- [File type associations](https://learn.microsoft.com/en-us/windows/uwp/launch-resume/handle-file-activation)
- [PowerShell XML Manipulation](https://learn.microsoft.com/en-us/powershell/scripting/samples/working-with-xml)
- [App Extensions](https://learn.microsoft.com/en-us/windows/uwp/launch-resume/how-to-create-an-extension)

### Tools and Utilities
- [Windows SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/)
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
- [SignTool Documentation](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool)