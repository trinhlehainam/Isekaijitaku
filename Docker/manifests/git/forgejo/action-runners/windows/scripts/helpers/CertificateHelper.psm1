using module .\LogHelper.psm1

function Get-CertificatePaths {
    param (
        [string]$PathList
    )

    if ([string]::IsNullOrWhiteSpace($PathList)) {
        return @()
    }

    # Split by comma and trim whitespace
    $paths = $PathList -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    
    # Valid certificate extensions
    $validExtensions = @('.cer', '.crt', '.pem')
    
    # Store all valid certificate file paths
    $certFiles = @()
    
    foreach ($path in $paths) {
        if (-not (Test-Path $path)) {
            Write-Log -Level "WARN" -Message "Path not found: $path"
            continue
        }

        # Check if path is a directory
        if ((Get-Item $path) -is [System.IO.DirectoryInfo]) {
            # Get all certificate files from directory
            $files = Get-ChildItem -Path $path -Recurse | Where-Object {
                $_.Extension -in $validExtensions
            }
            if ($files.Count -eq 0) {
                Write-Log -Level "WARN" -Message "No certificate files found in directory: $path"
            } else {
                $certFiles += $files.FullName
            }
        }
        # Check if path is a file with valid extension
        elseif ($validExtensions -contains (Get-Item $path).Extension) {
            $certFiles += $path
        }
        else {
            Write-Log -Level "WARN" -Message "Invalid certificate file extension: $path"
        }
    }

    Write-Log "Found $($certFiles.Count) certificate files"
    return $certFiles
}

function Install-Certificate {
    param (
        [string]$CertPath
    )
    
    try {
        Write-Log "Installing certificate: $CertPath"
        
        # Read certificate content
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
        
        # Determine certificate store based on certificate type
        $store = "CA"  # Default to CA store
        if ($cert.HasPrivateKey) {
            $store = "My"  # Personal store for certificates with private keys
        }
        
        Write-Log "Installing to LocalMachine\$store store"
        
        # Import certificate to LocalMachine store
        $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store($store, "LocalMachine")
        $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        
        try {
            $certStore.Add($cert)
            Write-Log "Successfully installed certificate: $($cert.Subject)"
            return $true
        }
        finally {
            $certStore.Close()
        }
    }
    catch {
        Write-Error-Log "Failed to install certificate ${CertPath}: $_"
        return $false
    }
}

function Install-Certificates {
    param (
        [string]$CertFiles
    )

    $success = $true
    $certPaths = Get-CertificatePaths -PathList $CertFiles

    if ($certPaths.Count -eq 0) {
        Write-Log "No valid certificate files found"
        return $true
    }

    foreach ($certPath in $certPaths) {
        if (-not (Install-Certificate -CertPath $certPath)) {
            $success = $false
        }
    }

    return $success
}
