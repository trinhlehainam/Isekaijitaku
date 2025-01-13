function Install-Certificate {
    param (
        [string]$CertPath
    )
    
    try {
        Write-Host "Installing certificate: $CertPath"
        
        # Read certificate content
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
        
        # Determine certificate store based on certificate type
        $store = "CA"  # Default to CA store
        if ($cert.HasPrivateKey) {
            $store = "My"  # Personal store for certificates with private keys
        }
        
        Write-Host "Installing to LocalMachine\$store store"
        
        # Import certificate to LocalMachine store
        $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store($store, "LocalMachine")
        $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        
        try {
            $certStore.Add($cert)
            Write-Host "Successfully installed certificate: $($cert.Subject)"
            return $true
        }
        finally {
            $certStore.Close()
        }
    }
    catch {
        Write-Error "Failed to install certificate ${CertPath}: $_"
        return $false
    }
}

function Install-CertificatesFromDirectory {
    param (
        [string]$DirPath
    )

    if (-not (Test-Path $DirPath)) {
        Write-Warning "Certificate directory '$DirPath' does not exist"
        return $false
    }

    Write-Host "Looking for certificates in: $DirPath"
    $certFiles = Get-ChildItem -Path $DirPath -Include @("*.cer", "*.crt", "*.pem") -Recurse
    
    if ($certFiles.Count -eq 0) {
        Write-Warning "No certificate files found in '$DirPath'"
        return $false
    }

    Write-Host "Found $($certFiles.Count) certificate files"
    $success = $true
    
    foreach ($certFile in $certFiles) {
        if (-not (Install-Certificate -CertPath $certFile.FullName)) {
            $success = $false
        }
    }
    
    return $success
}

function Install-CertificatesFromPath {
    param (
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $true
    }

    if (-not (Test-Path $Path)) {
        Write-Warning "Path '$Path' does not exist"
        return $false
    }

    if ((Get-Item $Path) -is [System.IO.DirectoryInfo]) {
        return Install-CertificatesFromDirectory -DirPath $Path
    }
    else {
        return Install-Certificate -CertPath $Path
    }
}

Export-ModuleMember -Function @('Install-Certificate', 'Install-CertificatesFromDirectory', 'Install-CertificatesFromPath')
