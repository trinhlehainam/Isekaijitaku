function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN'  { 'Yellow' }
        default { 'White' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-Error-Log {
    param(
        [string]$Message
    )
    Write-Log -Message $Message -Level ERROR
}

function Write-Error-Log-And-Throw {
    param(
        [string]$Message
    )
    Write-Error-Log $Message
    throw $Message
}
