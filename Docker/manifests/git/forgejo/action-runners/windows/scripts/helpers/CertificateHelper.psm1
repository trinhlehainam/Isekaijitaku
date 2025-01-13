# Import functions from CertificateHelper.ps1
. $PSScriptRoot\CertificateHelper.ps1

# Export functions
Export-ModuleMember -Function Get-CertificatePaths, Install-Certificate, Install-Certificates
