param (
    [string]$InstallPath,
    [string]$Version="22.13.0",
    [switch]$InstallPnpm
)

if (-not $PSBoundParameters.ContainsKey('InstallPnpm')) {
    $InstallPnpm = $true
}

$nodePath = Join-Path $InstallPath "Node"

# https://nodejs.org/en/download
$downloadUrl = "https://nodejs.org/dist/v${Version}/node-v${Version}-win-x64.zip"
$zipPath = Invoke-DownloadWithRetry $downloadUrl
Expand-Archive -Path $zipPath -DestinationPath $installPath

# Rename extracted folder
$currentNodePath = "$installPath/node-v${Version}-win-x64"
if (-not (Test-Path $currentNodePath)) {
    Write-Log "Could not find $currentNodePath after extraction"
    exit 1
}
Rename-Item $currentNodePath $nodePath

# Remove zip file
Remove-Item $zipPath

# Add Node binaries to the path
$env:Path += ";$nodePath"

if ($InstallPnpm) {
    Write-Log "Installing pnpm..."
    corepack enable pnpm
}