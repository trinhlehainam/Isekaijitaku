# Ref: https://github.com/actions/runner-images/blob/main/images/windows/scripts/helpers/InstallHelpers.ps1

function Install-Binary {
    <#
    .SYNOPSIS
        A function to install binaries from either a URL or a local path.

    .DESCRIPTION
        This function downloads and installs .exe or .msi binaries from a specified URL or a local path. It also supports checking the binary's signature and SHA256/SHA512 sum before installation.

    .PARAMETER Url
        The URL from which the binary will be downloaded. This parameter is required if LocalPath is not specified.

    .PARAMETER LocalPath
        The local path of the binary to be installed. This parameter is required if Url is not specified.

    .PARAMETER Type
        The type of the binary to be installed. Valid values are "MSI" and "EXE". If not specified, the type is inferred from the file extension.

    .PARAMETER InstallArgs
        The list of arguments that will be passed to the installer. Cannot be used together with ExtraInstallArgs.

    .PARAMETER ExtraInstallArgs
        Additional arguments that will be passed to the installer. Cannot be used together with InstallArgs.

    .PARAMETER ExpectedSignature
        The expected signature of the binary. If specified, the binary's signature is checked before installation.

    .PARAMETER ExpectedSHA256Sum
        The expected SHA256 sum of the binary. If specified, the binary's SHA256 sum is checked before installation.

    .PARAMETER ExpectedSHA512Sum
        The expected SHA512 sum of the binary. If specified, the binary's SHA512 sum is checked before installation.

    .EXAMPLE
        Install-Binary -Url "https://go.microsoft.com/fwlink/p/?linkid=2083338" -Type EXE -InstallArgs ("/features", "+", "/quiet") -ExpectedSignature "A5C7D5B7C838D5F89DDBEDB85B2C566B4CDA881F"
    #>
    Param
    (
        [Parameter(Mandatory, ParameterSetName = "Url")]
        [String] $Url,
        [Parameter(Mandatory, ParameterSetName = "LocalPath")]
        [String] $LocalPath,
        [ValidateSet("MSI", "EXE")]
        [String] $Type,
        [String[]] $InstallArgs,
        [String[]] $ExtraInstallArgs,
        [String[]] $ExpectedSignature,
        [String] $ExpectedSHA256Sum,
        [String] $ExpectedSHA512Sum
    )

    if ($PSCmdlet.ParameterSetName -eq "LocalPath") {
        if (-not (Test-Path -Path $LocalPath)) {
            throw "LocalPath parameter is specified, but the file does not exist."
        }
        if (-not $Type) {
            $Type = ([System.IO.Path]::GetExtension($LocalPath)).Replace(".", "").ToUpper()
            if ($Type -ne "MSI" -and $Type -ne "EXE") {
                throw "LocalPath parameter is specified, but the file extension is not .msi or .exe. Please specify the Type parameter."
            }
        }
        $filePath = $LocalPath
    } else {
        if (-not $Type) {
            $Type = ([System.IO.Path]::GetExtension($Url)).Replace(".", "").ToUpper()
            if ($Type -ne "MSI" -and $Type -ne "EXE") {
                throw "Cannot determine the file type from the URL. Please specify the Type parameter."
            }
            $fileName = [System.IO.Path]::GetFileName($Url)
        } else {
            $fileName = [System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetRandomFileName()) + ".$Type".ToLower()
        }
        $filePath = Invoke-DownloadWithRetry -Url $Url -Path "${env:TEMP_DIR}\$fileName"
    }

    if ($PSBoundParameters.ContainsKey('ExpectedSignature')) {
        if ($ExpectedSignature) {
            Test-FileSignature -Path $filePath -ExpectedThumbprint $ExpectedSignature
        } else {
            throw "ExpectedSignature parameter is specified, but no signature is provided."
        }
    }

    if ($ExpectedSHA256Sum) {
        Test-FileChecksum $filePath -ExpectedSHA256Sum $ExpectedSHA256Sum
    }

    if ($ExpectedSHA512Sum) {
        Test-FileChecksum $filePath -ExpectedSHA512Sum $ExpectedSHA512Sum
    }

    if ($ExtraInstallArgs -and $InstallArgs) {
        throw "InstallArgs and ExtraInstallArgs parameters cannot be used together."
    }

    if ($Type -eq "MSI") {
        # MSI binaries should be installed via msiexec.exe
        if ($ExtraInstallArgs) {
            $InstallArgs = @('/i', $filePath, '/qn', '/norestart') + $ExtraInstallArgs
        } elseif (-not $InstallArgs) {
            Write-Host "No arguments provided for MSI binary. Using default arguments: /i, /qn, /norestart"
            $InstallArgs = @('/i', $filePath, '/qn', '/norestart')
        }
        $filePath = "msiexec.exe"
    } else {
        # EXE binaries should be started directly
        if ($ExtraInstallArgs) {
            $InstallArgs = $ExtraInstallArgs
        }
    }

    $installStartTime = Get-Date
    Write-Host "Starting Install $Name..."
    try {
        $process = Start-Process -FilePath $filePath -ArgumentList $InstallArgs -Wait -PassThru
        $exitCode = $process.ExitCode
        $installCompleteTime = [math]::Round(($(Get-Date) - $installStartTime).TotalSeconds, 2)
        if ($exitCode -eq 0) {
            Write-Host "Installation successful in $installCompleteTime seconds"
        } elseif ($exitCode -eq 3010) {
            Write-Host "Installation successful in $installCompleteTime seconds. Reboot is required."
        } else {
            Write-Host "Installation process returned unexpected exit code: $exitCode"
            Write-Host "Time elapsed: $installCompleteTime seconds"
            exit $exitCode
        }
    } catch {
        $installCompleteTime = [math]::Round(($(Get-Date) - $installStartTime).TotalSeconds, 2)
        Write-Host "Installation failed in $installCompleteTime seconds"
    }
}

function Invoke-DownloadWithRetry {
    Param
    (
        [Parameter(Mandatory)]
        [string] $Url,
        [Alias("Destination")]
        [string] $Path
    )

    if (-not $Path) {
        $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
        $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
        $fileName = [IO.Path]::GetFileName($Url) -replace $re

        if ([String]::IsNullOrEmpty($fileName)) {
            $fileName = [System.IO.Path]::GetRandomFileName()
        }
        $Path = Join-Path -Path "${env:TEMP}" -ChildPath $fileName
    }

    Write-Host "Downloading package from $Url to $Path..."

    $interval = 30
    $downloadStartTime = Get-Date
    for ($retries = 20; $retries -gt 0; $retries--) {
        try {
            $attemptStartTime = Get-Date
            (New-Object System.Net.WebClient).DownloadFile($Url, $Path)
            $attemptSeconds = [math]::Round(($(Get-Date) - $attemptStartTime).TotalSeconds, 2)
            Write-Host "Package downloaded in $attemptSeconds seconds"
            break
        } catch {
            $attemptSeconds = [math]::Round(($(Get-Date) - $attemptStartTime).TotalSeconds, 2)
            Write-Warning "Package download failed in $attemptSeconds seconds"
            Write-Warning $_.Exception.Message

            if ($_.Exception.InnerException.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
                Write-Warning "Request returned 404 Not Found. Aborting download."
                $retries = 0
            }
        }

        if ($retries -eq 0) {
            $totalSeconds = [math]::Round(($(Get-Date) - $downloadStartTime).TotalSeconds, 2)
            throw "Package download failed after $totalSeconds seconds"
        }

        Write-Warning "Waiting $interval seconds before retrying (retries left: $retries)..."
        Start-Sleep -Seconds $interval
    }

    return $Path
}

function Test-IsWin25 {
    (Get-CimInstance -ClassName Win32_OperatingSystem).Caption -match "2025"
}

function Test-IsWin22 {
    (Get-CimInstance -ClassName Win32_OperatingSystem).Caption -match "2022"
}

function Test-IsWin19 {
    (Get-CimInstance -ClassName Win32_OperatingSystem).Caption -match "2019"
}

function Expand-7ZipArchive {
    Param
    (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath,
        [ValidateSet("x", "e")]
        [char] $ExtractMethod = "x"
    )

    Write-Host "Expand archive '$PATH' to '$DestinationPath' directory"
    7z.exe $ExtractMethod "$Path" -o"$DestinationPath" -y | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "There is an error during expanding '$Path' to '$DestinationPath' directory"
        exit 1
    }
}

function Get-WindowsUpdateStates {
    $completedUpdates = @{}
    $filter = @{
        LogName      = "System"
        Id           = 19, 20, 43
        ProviderName = "Microsoft-Windows-WindowsUpdateClient"
    }
    $events = Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue | Sort-Object Id

    foreach ( $event in $events ) {
        switch ( $event.Id ) {
            19 {
                $state = "Installed"
                $title = $event.Properties[0].Value
                $completedUpdates[$title] = ""
                break
            }
            20 {
                $state = "Failed"
                $title = $event.Properties[1].Value
                $completedUpdates[$title] = ""
                break
            }
            43 {
                $state = "Running"
                $title = $event.Properties[0].Value
                break
            }
        }

        # Skip update started event if it was already completed
        if ( $state -eq "Running" -and $completedUpdates.ContainsKey($title) ) {
            continue
        }

        [PSCustomObject]@{
            State = $state
            Title = $title
        }
    }
}

function Invoke-ScriptBlockWithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic.

    .DESCRIPTION
        The Invoke-ScriptBlockWithRetry function executes a specified script block with retry logic. It allows you to specify the number of retries and the interval between retries.

    .PARAMETER Command
        The script block to be executed.

    .PARAMETER RetryCount
        The number of times to retry executing the script block. The default value is 10.

    .PARAMETER RetryIntervalSeconds
        The interval in seconds between each retry. The default value is 5.

    .EXAMPLE
        Invoke-ScriptBlockWithRetry -Command { Get-Process } -RetryCount 3 -RetryIntervalSeconds 10
        This example executes the script block { Get-Process } with 3 retries and a 10-second interval between each retry.

    #>

    param (
        [scriptblock] $Command,
        [int] $RetryCount = 10,
        [int] $RetryIntervalSeconds = 5
    )

    while ($RetryCount -gt 0) {
        try {
            & $Command
            return
        } catch {
            Write-Host "There is an error encountered:`n $_"
            $RetryCount--

            if ($RetryCount -eq 0) {
                exit 1
            }

            Write-Host "Waiting $RetryIntervalSeconds seconds before retrying. Retries left: $RetryCount"
            Start-Sleep -Seconds $RetryIntervalSeconds
        }
    }
}
function Get-ChecksumFromUrl {
    <#
    .SYNOPSIS
        Retrieves the checksum hash for a file from a given URL.

    .DESCRIPTION
        The Get-ChecksumFromUrl function retrieves the checksum hash for a specified file
        from a given URL. It supports SHA256 and SHA512 hash types.

    .PARAMETER Url
        The URL of the checksum file.

    .PARAMETER FileName
        The name of the file to retrieve the checksum hash for.

    .PARAMETER HashType
        The type of hash to retrieve. Valid values are "SHA256" and "SHA512".

    .EXAMPLE
        Get-ChecksumFromUrl -Url "https://example.com/checksums.txt" -FileName "file.txt" -HashType "SHA256"
        Retrieves the SHA256 checksum hash for the file "file.txt" from the URL "https://example.com/checksums.txt".
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string] $Url,
        [Parameter(Mandatory = $true)]
        [Alias("File", "Asset")]
        [string] $FileName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("SHA256", "SHA512")]
        [Alias("Type")]
        [string] $HashType
    )

    $tempFile = Join-Path -Path $env:TEMP_DIR -ChildPath ([System.IO.Path]::GetRandomFileName())
    $checksums = (Invoke-DownloadWithRetry -Url $Url -Path $tempFile | Get-Item | Get-Content) -as [string[]]
    Remove-Item -Path $tempFile

    $matchedLine = $checksums | Where-Object { $_ -like "*$FileName*" }
    if ($matchedLine.Count -gt 1) {
        throw "Found multiple lines matching file name '${FileName}' in checksum file."
    } elseif ($matchedLine.Count -eq 0) {
        throw "File name '${FileName}' not found in checksum file."
    }

    if ($HashType -eq "SHA256") {
        $pattern = "[A-Fa-f0-9]{64}"
    } elseif ($HashType -eq "SHA512") {
        $pattern = "[A-Fa-f0-9]{128}"
    } else {
        throw "Unknown hash type: ${HashType}"
    }
    Write-Debug "Found line matching file name '${FileName}' in checksum file:`n${matchedLine}"

    $hash = $matchedLine | Select-String -Pattern $pattern | ForEach-Object { $_.Matches.Value }
    if ([string]::IsNullOrEmpty($hash)) {
        throw "Found '${FileName}' in checksum file, but failed to get hash from it.`nLine: ${matchedLine}"
    }
    Write-Host "Found hash for ${FileName} in checksum file: $hash"

    return $hash
}
function Test-FileChecksum {
    <#
    .SYNOPSIS
        Verifies the checksum of a file.

    .DESCRIPTION
        The Test-FileChecksum function verifies the SHA256 or SHA512 checksum of a file against an expected value. 
        If the checksum does not match the expected value, the function throws an error.

    .PARAMETER Path
        The path to the file for which to verify the checksum.

    .PARAMETER ExpectedSHA256Sum
        The expected SHA256 checksum. If this parameter is provided, the function will calculate the SHA256 checksum of the file and compare it to this value.

    .PARAMETER ExpectedSHA512Sum
        The expected SHA512 checksum. If this parameter is provided, the function will calculate the SHA512 checksum of the file and compare it to this value.

    .EXAMPLE
        Test-FileChecksum -Path "C:\temp\file.txt" -ExpectedSHA256Sum "ABC123"

        Verifies that the SHA256 checksum of the file at C:\temp\file.txt is ABC123.

    .EXAMPLE
        Test-FileChecksum -Path "C:\temp\file.txt" -ExpectedSHA512Sum "DEF456"

        Verifies that the SHA512 checksum of the file at C:\temp\file.txt is DEF456.

    #>


    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path,
        [Parameter(Mandatory = $false)]
        [String] $ExpectedSHA256Sum,
        [Parameter(Mandatory = $false)]
        [String] $ExpectedSHA512Sum
    )

    Write-Verbose "Performing checksum verification"

    if ($ExpectedSHA256Sum -and $ExpectedSHA512Sum) {
        throw "Only one of the ExpectedSHA256Sum and ExpectedSHA512Sum parameters can be provided"
    }

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    if ($ExpectedSHA256Sum) {
        $fileHash = (Get-FileHash -Path $Path -Algorithm SHA256).Hash
        $expectedHash = $ExpectedSHA256Sum
    }

    if ($ExpectedSHA512Sum) {
        $fileHash = (Get-FileHash -Path $Path -Algorithm SHA512).Hash
        $expectedHash = $ExpectedSHA512Sum
    }

    if ($fileHash -ne $expectedHash) {
        throw "Checksum verification failed: expected $expectedHash, got $fileHash"
    } else {
        Write-Verbose "Checksum verification passed"
    }
}

function Test-FileSignature {
    <#
    .SYNOPSIS
        Tests the file signature of a given file.

    .DESCRIPTION
        The Test-FileSignature function checks the signature of a file against the expected thumbprints. 
        It uses the Get-AuthenticodeSignature cmdlet to retrieve the signature information of the file.
        If the signature status is not valid or the thumbprint does not match the expected thumbprints, an exception is thrown.

    .PARAMETER Path
        Specifies the path of the file to test.

    .PARAMETER ExpectedThumbprint
        Specifies the expected thumbprints to match against the file's signature.

    .EXAMPLE
        Test-FileSignature -Path "C:\Path\To\File.exe" -ExpectedThumbprint "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0"

        This example tests the signature of the file "C:\Path\To\File.exe" against the expected thumbprint "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0".

    #>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path,
        [Parameter(Mandatory = $true)]
        [string[]] $ExpectedThumbprint
    )

    $signature = Get-AuthenticodeSignature $Path

    if ($signature.Status -ne "Valid") {
        throw "Signature status is not valid. Status: $($signature.Status)"
    }

    foreach ($thumbprint in $ExpectedThumbprint) {
        if ($signature.SignerCertificate.Thumbprint.Contains($thumbprint)) {
            Write-Output "Signature for $Path is valid"
            $signatureMatched = $true
            return
        }
    }

    if ($signatureMatched) {
        Write-Output "Signature for $Path is valid"
    } else {
        throw "Signature thumbprint do not match expected."
    }
}

function Update-Environment {
    <#
    .SYNOPSIS
        Updates the environment variables by reading values from the registry.

    .DESCRIPTION
        This function updates current environment by reading values from the registry.
        It is useful when you need to update the environment variables without restarting the current session.

    .NOTES
        The function requires administrative privileges to modify the system registry.
    #>

    $locations = @(
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
        'HKCU:\Environment'
    )

    # Update PATH variable
    $pathItems = $locations | ForEach-Object {
        (Get-Item $_).GetValue('PATH').Split(';')
    } | Select-Object -Unique
    $env:PATH = $pathItems -join ';'

    # Update other variables
    $locations | ForEach-Object {
        $key = Get-Item $_
        foreach ($name in $key.GetValueNames()) {
            $value = $key.GetValue($name)
            if (-not ($name -ieq 'PATH')) {
                Set-Item -Path Env:$name -Value $value
            }
        }
    }
}