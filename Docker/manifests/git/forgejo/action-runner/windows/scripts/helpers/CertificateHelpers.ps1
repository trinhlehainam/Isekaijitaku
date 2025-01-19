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
        Import-Certificate -FilePath $CertPath -CertStoreLocation "Cert:\LocalMachine\Root"
        Write-Log "Successfully installed certificate: $(Get-ChildItem -Path $CertPath)"
        return $true
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

# https://github.com/nodejs/node/issues/51537
function Install-NodeExtraCaCerts {
    param (
        [string]$CertFiles
    )
    
    $nodePath = Get-Command "node" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
    # Check if Node.js is installed
    if (-not $nodePath) {
        Write-Log "Node.js is not installed"
        return $true
    }
    
    # Get all certificates from the list
    $certPaths = Get-CertificatePaths -PathList $CertFiles
    if ($certPaths.Count -eq 0) {
        Write-Log "No valid certificate files found"
        return $true
    }

    # Get Node.js directory and extra-ca-certs file path
    $nodeDir = [System.IO.Path]::GetDirectoryName($nodePath)
    $extraCaCertsPath = Join-Path $nodeDir "extra-ca-certs\root_ca.crt"

    if (-not (Test-Path $extraCaCertsPath)) {
        New-Item -ItemType Directory -Path (Split-Path $extraCaCertsPath) -Force | Out-Null
    }

    try {
        # Create fresh certificate file by concatenating all certificates
        $certContents = @()
        foreach ($certPath in $certPaths) {
            Write-Log "Reading certificate from $certPath"
            $content = Get-Content -Path $certPath -Raw -ErrorAction Stop
            $certContents += $content
        }
        
        # Write certificates to file with proper line endings
        Write-Log "Writing certificates to $extraCaCertsPath"
        $combinedCerts = $certContents -join "`n"
        Set-Content -Path $extraCaCertsPath -Value $combinedCerts -Force -ErrorAction Stop -NoNewline
        
        # Set environment variable
        $env:NODE_EXTRA_CA_CERTS = $extraCaCertsPath
        [Environment]::SetEnvironmentVariable("NODE_EXTRA_CA_CERTS", $extraCaCertsPath, "Machine")
        Write-Log "Set NODE_EXTRA_CA_CERTS to $extraCaCertsPath"
        
        return $true
    }
    catch {
        Write-Error "Failed to process certificates: $_"
        return $false
    }
}