# Log Helper Functions
$script:logFile = $null
$script:errorLogFile = $null

function Set-LogFile {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path
    )

    $script:logFile = $Path
}

function Set-ErrorLogFile {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path
    )

    $script:errorLogFile = $Path
}

function Format-LogMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    return "[$timestamp] $Level $Message"
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $logMessage = Format-LogMessage -Level '[INFO]' -Message $Message
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

    $logMessage = Format-LogMessage -Level '[INFO]' -Message $Message
    Write-Host $logMessage -ForegroundColor Green
    
    if ($script:logFile) {
        Add-Content -Path $script:logFile -Value $logMessage
    }
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $logMessage = Format-LogMessage -Level '[ERROR]' -Message $Message
    Write-Host $logMessage -ForegroundColor Red
    
    if ($ErrorRecord) {
        $errorDetails = Format-LogMessage -Level '[ERROR]' -Message "Details: $($ErrorRecord.Exception.Message)"
        Write-Host $errorDetails -ForegroundColor Red
        
        if ($script:errorLogFile) {
            Add-Content -Path $script:errorLogFile -Value $errorDetails
        }
        elseif ($script:logFile) {
            Add-Content -Path $script:logFile -Value $errorDetails
        }
    }
    
    if ($script:errorLogFile) {
        Add-Content -Path $script:errorLogFile -Value $logMessage
    }
    elseif ($script:logFile) {
        Add-Content -Path $script:logFile -Value $logMessage
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Set-LogFile',
    'Write-Log',
    'Write-SuccessLog',
    'Write-ErrorLog'
)
