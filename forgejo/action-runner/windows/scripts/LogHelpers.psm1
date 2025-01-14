# LogHelpers.psm1
# Shared logging functions for Gitea Runner scripts

# Default log file path and settings
$script:LogFile = ""
$script:MaxLogSizeMB = 10
$script:MaxLogFiles = 5

function Set-LogFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxSizeMB = 10,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxFiles = 5
    )
    
    $script:LogFile = $Path
    $script:MaxLogSizeMB = $MaxSizeMB
    $script:MaxLogFiles = $MaxFiles
    
    # Create log directory if it doesn't exist
    $logDir = Split-Path -Parent $Path
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    
    # Create log file if it doesn't exist
    if (-not (Test-Path $Path)) {
        New-Item -ItemType File -Force -Path $Path | Out-Null
    }
}

function Rotate-Logs {
    if (-not $script:LogFile -or -not (Test-Path $script:LogFile)) {
        return
    }
    
    $logFileInfo = Get-Item $script:LogFile
    if ($logFileInfo.Length/1MB -gt $script:MaxLogSizeMB) {
        $baseName = $logFileInfo.BaseName
        $extension = $logFileInfo.Extension
        $directory = $logFileInfo.DirectoryName
        
        # Rotate existing log files
        for ($i = $script:MaxLogFiles - 1; $i -gt 0; $i--) {
            $oldFile = Join-Path $directory "$baseName.$i$extension"
            $newFile = Join-Path $directory "$baseName.$($i+1)$extension"
            if (Test-Path $oldFile) {
                Move-Item -Path $oldFile -Destination $newFile -Force
            }
        }
        
        # Move current log to .1
        Move-Item -Path $script:LogFile -Destination (Join-Path $directory "$baseName.1$extension") -Force
        New-Item -ItemType File -Force -Path $script:LogFile | Out-Null
    }
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
        try {
            Add-Content -Path $script:LogFile -Value $logMessage
            Rotate-Logs
        } catch {
            Write-Host "ERROR: Failed to write to log file: $_" -ForegroundColor Red
        }
    }
}

function Write-ErrorLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    $errorMessage = "ERROR: $Message"
    if ($ErrorRecord) {
        $errorMessage += "`nDetails: $($ErrorRecord.Exception.Message)"
        $errorMessage += "`nStack Trace: $($ErrorRecord.ScriptStackTrace)"
    }
    Write-Log -Message $errorMessage -ForegroundColor Red
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

function Write-DebugLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    if ($env:GITEA_RUNNER_DEBUG -eq "true") {
        Write-Log -Message "DEBUG: $Message" -ForegroundColor Cyan
    }
}

# Export functions
Export-ModuleMember -Function Set-LogFile, Write-Log, Write-ErrorLog, Write-SuccessLog, Write-WarningLog, Write-DebugLog
