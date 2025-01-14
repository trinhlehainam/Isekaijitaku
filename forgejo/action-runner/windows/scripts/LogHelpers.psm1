# LogHelpers.psm1
# Shared logging functions for Gitea Runner scripts

# Default log file path
$script:LogFile = ""

function Set-LogFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    $script:LogFile = $Path
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # Write to console
    Write-Host $logMessage -ForegroundColor $ForegroundColor
    
    # Write to log file if set
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Log -Message "ERROR: $Message" -ForegroundColor Red
}

function Write-SuccessLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Log -Message $Message -ForegroundColor Green
}

function Write-WarningLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Log -Message "WARNING: $Message" -ForegroundColor Yellow
}

# Export functions
Export-ModuleMember -Function Set-LogFile, Write-Log, Write-ErrorLog, Write-SuccessLog, Write-WarningLog
