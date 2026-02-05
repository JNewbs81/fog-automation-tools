#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uploads BIOS tools to FOG server for network-based USB boot
.DESCRIPTION
    This script uses SCP to upload the bios-tools folder to your FOG server
    so all USB sticks can download the latest files automatically.
#>

param(
    [string]$FogServer = "192.168.1.211",
    [string]$FogUser = "fog"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Upload BIOS Tools to FOG Server" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if bios-tools folder exists
$BiosToolsPath = "$PSScriptRoot\bios-tools"
if (-not (Test-Path $BiosToolsPath)) {
    Write-Host "ERROR: bios-tools folder not found at $BiosToolsPath" -ForegroundColor Red
    exit 1
}

Write-Host "FOG Server: $FogServer" -ForegroundColor Yellow
Write-Host "FOG User: $FogUser" -ForegroundColor Yellow
Write-Host ""

# Check if we have scp (comes with Windows 10/11)
$scpPath = Get-Command scp -ErrorAction SilentlyContinue
if (-not $scpPath) {
    Write-Host "ERROR: scp command not found." -ForegroundColor Red
    Write-Host "Please install OpenSSH Client from Windows Optional Features." -ForegroundColor Yellow
    exit 1
}

Write-Host "Step 1: Creating directory on FOG server..." -ForegroundColor Yellow
$createDir = "ssh ${FogUser}@${FogServer} 'sudo mkdir -p /var/www/html/fog-automation-tools && sudo chown -R ${FogUser}:${FogUser} /var/www/html/fog-automation-tools'"
Write-Host "  Running: $createDir" -ForegroundColor Gray
Invoke-Expression $createDir

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create directory on FOG server" -ForegroundColor Red
    Write-Host "Make sure you can SSH to the FOG server as user '$FogUser'" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Directory created" -ForegroundColor Green
Write-Host ""

Write-Host "Step 2: Uploading BIOS tools to FOG server..." -ForegroundColor Yellow
Write-Host "  This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

# Upload the entire bios-tools folder
scp -r "$BiosToolsPath" "${FogUser}@${FogServer}:/var/www/html/fog-automation-tools/"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to upload files to FOG server" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Setting permissions on FOG server..." -ForegroundColor Yellow
$setPerms = "ssh ${FogUser}@${FogServer} 'sudo chmod -R 755 /var/www/html/fog-automation-tools'"
Invoke-Expression $setPerms

if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Could not set permissions (files may still work)" -ForegroundColor Yellow
} else {
    Write-Host "  Permissions set" -ForegroundColor Green
}
Write-Host ""

Write-Host "================================================" -ForegroundColor Green
Write-Host "SUCCESS! Files uploaded to FOG server" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Files are now available at:" -ForegroundColor Cyan
Write-Host "  http://${FogServer}/fog-automation-tools/bios-tools/" -ForegroundColor White
Write-Host ""
Write-Host "To test, open this URL in a web browser:" -ForegroundColor Yellow
Write-Host "  http://${FogServer}/fog-automation-tools/bios-tools/auto-detect-apply.bat" -ForegroundColor White
Write-Host ""
Write-Host "Your USB sticks will now download the latest files automatically!" -ForegroundColor Green
Write-Host ""
