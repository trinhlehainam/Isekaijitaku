function Test-RequiredEnvironmentVariables {
    param(
        [Parameter(Mandatory=$true)]
        [array]$RequiredVars,
        [switch]$ThrowOnError
    )

    $missingVars = @()

    foreach ($var in $RequiredVars) {
        $value = [Environment]::GetEnvironmentVariable($var.Name)
        if ([string]::IsNullOrWhiteSpace($value)) {
            $missingVars += $var
        }
    }

    if ($missingVars.Count -gt 0) {
        $errorMessage = "Missing required environment variables:`n"
        foreach ($var in $missingVars) {
            $errorMessage += "- $($var.Name): $($var.Description)`n"
        }
        
        if ($ThrowOnError) {
            throw $errorMessage
        } else {
            Write-Error $errorMessage
            return $false
        }
    }

    return $true
}

function Import-DotEnv {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Target = 'Process'
    )

    if (Test-Path $Path) {
        Write-Log "Loading environment from: $Path"
        
        try {
            # https://stackoverflow.com/questions/72236557/how-do-i-read-a-env-file-from-a-ps1-script
            Get-Content $Path | ForEach-Object {
                $name, $value = $_.split('=')
                if (-not [string]::IsNullOrWhiteSpace($name) -and -not $name.Contains('#')) {
                    [Environment]::SetEnvironmentVariable($name, $value, $Target)
                }
            }
            Write-Log "Environment loaded successfully"
        } catch {
            Write-ErrorLog "Failed to load .env file: $_"
        }
    } else {
        Write-Log "No .env file found at: $Path"
    }
}

Export-ModuleMember -Function @(
    'Test-RequiredEnvironmentVariables',
    'Import-DotEnv'
)
