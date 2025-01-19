# Import required modules

# Import helper scripts
. $PSScriptRoot\InstallHelpers.ps1
Export-ModuleMember -Function @(
    'Install-Binary'
    'Invoke-DownloadWithRetry'
    'Invoke-ScriptBlockWithRetry'
    'Test-FileSignature'
    'Test-FileChecksum'
    'Update-Environment'
)

# Export functions from UnityInstallHelpers.ps1
. $PSScriptRoot\UnityInstallHelpers.ps1
Export-ModuleMember -Function @(
    'Install-UnityEditor'
    'Install-UnityEditorModules'
    'Get-UnityChangeSet'
    'Get-UnityEditorPath'
    'Get-UnityHubPath'
    'Get-UnityEditorInstallPath'
    'Get-InstalledUnityEditorVersions'
)

# Export functions from VisualStudioHelpers.ps1
. $PSScriptRoot\VisualStudioHelpers.ps1
Export-ModuleMember -Function @(
    'Install-VisualStudioBuildTools'
    'Get-VisualStudioBuildToolsInstances'
    'Get-VisualStudioInstancePackageIds'
)