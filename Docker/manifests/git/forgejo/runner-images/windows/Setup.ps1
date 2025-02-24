# Install VSSetup module if not already installed
if (-not (Get-Module -ListAvailable -Name VSSetup)) {
    Write-Log "Installing VSSetup module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module VSSetup -RequiredVersion 2.2.16 -Scope CurrentUser -Force
}

# Install ImageHelpers module if not already installed
# References:
# - PowerShell Module Installation: https://learn.microsoft.com/en-us/powershell/scripting/developer/module/installing-a-powershell-module
# - Module Path Locations: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath
# - Module Building Basics: https://powershellexplained.com/2017-05-27-Powershell-module-building-basics
# - Installing Custom-Module with Install-Module: https://stackoverflow.com/a/65872546
$moduleName = "ImageHelpers"
$installedModule = Get-Module -Name $moduleName -ListAvailable

if (-not $installedModule) {
    # Get user's PowerShell module directory
    $userModulePath = ($env:PSModulePath -split ';' | Where-Object { $_ -like "$HOME*" }) | Select-Object -First 1
    $moduleInstallPath = Join-Path $userModulePath $moduleName
    
    # Create module directory if it doesn't exist
    if (-not (Test-Path $moduleInstallPath)) {
        New-Item -Path $moduleInstallPath -ItemType Directory -Force | Out-Null
    }
    
    # Copy all files except excluded ones
    Get-ChildItem -Path $helpersPath -File | 
        Where-Object { $_.Name -notin $filesToExclude } |
        Copy-Item -Destination $moduleInstallPath -Force
}