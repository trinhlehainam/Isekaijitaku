function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = if ($Level -eq "ERROR") { "Red" } elseif ($Level -eq "WARN") { "Yellow" } else { "White" }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-Error-Log {
    param(
        [string]$Message
    )
    Write-Log -Level "ERROR" -Message $Message
}

function Write-Error-Log-And-Throw {
    param(
        [string]$Message
    )
    Write-Error-Log $Message
    throw $Message
}

Export-ModuleMember -Function @('Write-Log', 'Write-Error-Log', 'Write-Error-Log-And-Throw')
