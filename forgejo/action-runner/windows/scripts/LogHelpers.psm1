# LogHelpers.psm1
# Shared logging functions for Gitea Runner scripts

# Default log file path and settings
$script:logFile = $null

function Set-LogFile {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path
    )

    $script:logFile = $Path

    if ($Path) {
        # Create log directory if it doesn't exist
        $logDir = Split-Path -Parent $Path
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        }
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] $Message"
    
    Write-Host $logMessage

    if ($script:logFile) {
        Add-Content -Path $script:logFile -Value $logMessage
    }
}

function Write-SuccessLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] $Message"
    
    Write-Host $logMessage -ForegroundColor Green

    if ($script:logFile) {
        Add-Content -Path $script:logFile -Value $logMessage
    }
}

function Write-WarningLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] WARNING: $Message"
    
    Write-Host $logMessage -ForegroundColor Yellow

    if ($script:logFile) {
        Add-Content -Path $script:logFile -Value $logMessage
    }
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] ERROR: $Message"
    
    Write-Host $logMessage -ForegroundColor Red

    if ($script:logFile) {
        Add-Content -Path $script:logFile -Value $logMessage
    }
}

Export-ModuleMember -Function Set-LogFile, Write-Log, Write-SuccessLog, Write-WarningLog, Write-ErrorLog
