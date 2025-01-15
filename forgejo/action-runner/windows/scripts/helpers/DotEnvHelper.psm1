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
        [string]$EnvFile
    )

    if (Test-Path $EnvFile) {
        Write-Log "Loading environment from: $EnvFile"
        
        Get-Content $EnvFile | ForEach-Object {
            $name, $value = $_.split('=')
            if ([string]::IsNullOrWhiteSpace($name) -or $name.Contains('#') -or $value.Contains('#')) {
                continue
            }
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
        Write-Log "Environment loaded successfully"
    } else {
        Write-Log "No .env file found at: $EnvFile"
    }
}

Export-ModuleMember -Function @(
    'Test-RequiredEnvironmentVariables',
    'Import-DotEnv'
)
