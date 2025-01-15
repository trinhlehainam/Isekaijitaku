$script:LogFile = $null
$script:ErrorLogFile = $null

function Set-LogFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    $script:LogFile = $Path
}

function Set-ErrorLogFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    $script:ErrorLogFile = $Path
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    Write-Host $logMessage
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}

function Write-WarningLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $warningMessage = "[$timestamp] WARNING: $Message"
    
    Write-Host $warningMessage -ForegroundColor Yellow
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $warningMessage
    }
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errorMessage = "[$timestamp] ERROR: $Message"
    
    Write-Host $errorMessage -ForegroundColor Red
    if ($script:ErrorLogFile) {
        Add-Content -Path $script:ErrorLogFile -Value $errorMessage
    }
}

function Write-SuccessLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $successMessage = "[$timestamp] SUCCESS: $Message"
    
    Write-Host $successMessage -ForegroundColor Green
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $successMessage
    }
}

Export-ModuleMember -Function @(
    'Set-LogFile',
    'Set-ErrorLogFile',
    'Write-Log',
    'Write-ErrorLog',
    'Write-SuccessLog'
)
