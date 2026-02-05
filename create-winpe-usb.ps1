#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates a bootable WinPE USB for automated FOG BIOS configuration
.DESCRIPTION
    This script creates a WinPE USB that auto-runs BIOS configuration
    on Dell, HP, and Lenovo PCs for FOG imaging preparation.
.NOTES
    Run this script as Administrator!
#>

param(
    [string]$USBDriveLetter = "E"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "FOG BIOS Config - WinPE USB Creator" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$WinPEPath = "C:\WinPE_FOG"
$MountPath = "$WinPEPath\mount"
$MediaPath = "$WinPEPath\media"
$BootWim = "$MediaPath\sources\boot.wim"
$BiosToolsSource = "$PSScriptRoot\bios-tools"

# Verify WinPE exists
if (-not (Test-Path $BootWim)) {
    Write-Host "ERROR: WinPE not found at $BootWim" -ForegroundColor Red
    Write-Host "Please run the WinPE setup first." -ForegroundColor Red
    exit 1
}

# Verify bios-tools exists
if (-not (Test-Path $BiosToolsSource)) {
    Write-Host "ERROR: bios-tools folder not found at $BiosToolsSource" -ForegroundColor Red
    exit 1
}

Write-Host "Step 1: Mounting WinPE image..." -ForegroundColor Yellow
Dism /Mount-Image /ImageFile:$BootWim /Index:1 /MountDir:$MountPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to mount WinPE image" -ForegroundColor Red
    exit 1
}
Write-Host "  Mounted successfully" -ForegroundColor Green

Write-Host ""
Write-Host "Step 2: Copying BIOS tools into WinPE..." -ForegroundColor Yellow
$BiosToolsDest = "$MountPath\bios-tools"
# Remove old bios-tools folder if it exists to ensure fresh copy
if (Test-Path $BiosToolsDest) {
    Remove-Item -Path $BiosToolsDest -Recurse -Force
    Write-Host "  Removed old bios-tools folder" -ForegroundColor Gray
}
Copy-Item -Path $BiosToolsSource -Destination $BiosToolsDest -Recurse -Force
Write-Host "  Copied to $BiosToolsDest" -ForegroundColor Green

Write-Host ""
Write-Host "Step 3: Creating auto-run startup script..." -ForegroundColor Yellow

# Copy the server-based startup script
$StartnetSource = "$PSScriptRoot\startnet-server.cmd"
if (-not (Test-Path $StartnetSource)) {
    Write-Host "ERROR: startnet-server.cmd not found at $StartnetSource" -ForegroundColor Red
    exit 1
}

$StartnetContent = Get-Content $StartnetSource -Raw

$StartnetPath = "$MountPath\Windows\System32\startnet.cmd"
Set-Content -Path $StartnetPath -Value $StartnetContent -Encoding ASCII
Write-Host "  Created auto-run script at $StartnetPath" -ForegroundColor Green

Write-Host ""
Write-Host "Step 4: Unmounting and saving WinPE image..." -ForegroundColor Yellow
Dism /Unmount-Image /MountDir:$MountPath /Commit
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to unmount/commit WinPE image" -ForegroundColor Red
    Write-Host "Trying to discard changes..." -ForegroundColor Yellow
    Dism /Unmount-Image /MountDir:$MountPath /Discard
    exit 1
}
Write-Host "  WinPE image saved successfully" -ForegroundColor Green

Write-Host ""
Write-Host "Step 5: Creating bootable USB on drive ${USBDriveLetter}:..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  WARNING: This will ERASE all data on ${USBDriveLetter}:" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "  Type 'YES' to continue"
if ($confirm -ne "YES") {
    Write-Host "  Cancelled by user." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  You can manually create the USB later with:" -ForegroundColor Cyan
    Write-Host "  MakeWinPEMedia /UFD $MediaPath ${USBDriveLetter}:" -ForegroundColor White
    exit 0
}

# Use MakeWinPEMedia to create USB
$MakeWinPEMedia = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\MakeWinPEMedia.cmd"
& cmd /c "`"$MakeWinPEMedia`" /UFD $MediaPath ${USBDriveLetter}:"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "SUCCESS! Bootable USB created on ${USBDriveLetter}:" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "To use:" -ForegroundColor Cyan
    Write-Host "  1. Insert USB into target PC"
    Write-Host "  2. Boot from USB (may need to press F12/F11/F2)"
    Write-Host "  3. BIOS configures automatically"
    Write-Host "  4. PC reboots to PXE -> FOG"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "ERROR: Failed to create USB" -ForegroundColor Red
    Write-Host "You can try manually:" -ForegroundColor Yellow
    Write-Host "  MakeWinPEMedia /UFD $MediaPath ${USBDriveLetter}:" -ForegroundColor White
}

