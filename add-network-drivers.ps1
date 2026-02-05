#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Adds network drivers to WinPE for Lenovo and other systems
.DESCRIPTION
    This script injects network drivers into the WinPE boot.wim so that
    Lenovo ThinkCentre Tiny and other systems can get network connectivity.
.NOTES
    You need to download the network drivers first and place them in a folder.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DriverPath = "$PSScriptRoot\drivers\network"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Add Network Drivers to WinPE" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$WinPEPath = "C:\WinPE_FOG"
$MountPath = "$WinPEPath\mount"
$BootWim = "$WinPEPath\media\sources\boot.wim"

# Check if WinPE exists
if (-not (Test-Path $BootWim)) {
    Write-Host "ERROR: WinPE not found at $BootWim" -ForegroundColor Red
    Write-Host "Please run create-winpe-usb.ps1 first to create the WinPE environment." -ForegroundColor Red
    exit 1
}

# Check if driver folder exists
if (-not (Test-Path $DriverPath)) {
    Write-Host "ERROR: Driver folder not found at $DriverPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "To use this script:" -ForegroundColor Yellow
    Write-Host "1. Create folder: $DriverPath" -ForegroundColor White
    Write-Host "2. Download Lenovo network drivers (.inf files) and place them there" -ForegroundColor White
    Write-Host "3. Run this script again" -ForegroundColor White
    Write-Host ""
    Write-Host "For Lenovo ThinkCentre Tiny models, you can get drivers from:" -ForegroundColor Cyan
    Write-Host "  https://pcsupport.lenovo.com" -ForegroundColor White
    Write-Host "  Look for: Ethernet Adapter drivers (Intel or Realtek)" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Count driver files
$driverFiles = Get-ChildItem -Path $DriverPath -Filter "*.inf" -Recurse
if ($driverFiles.Count -eq 0) {
    Write-Host "ERROR: No .inf driver files found in $DriverPath" -ForegroundColor Red
    Write-Host "Please place network driver .inf files in this folder." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($driverFiles.Count) driver(s) to inject:" -ForegroundColor Green
foreach ($driver in $driverFiles) {
    Write-Host "  - $($driver.Name)" -ForegroundColor Gray
}
Write-Host ""

Write-Host "Step 1: Mounting WinPE image..." -ForegroundColor Yellow
Dism /Mount-Wim /WimFile:$BootWim /Index:1 /MountDir:$MountPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to mount WinPE image" -ForegroundColor Red
    exit 1
}
Write-Host "  Mounted successfully" -ForegroundColor Green
Write-Host ""

Write-Host "Step 2: Injecting network drivers..." -ForegroundColor Yellow
Dism /Image:$MountPath /Add-Driver /Driver:$DriverPath /Recurse /ForceUnsigned
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "WARNING: Some drivers may have failed to inject" -ForegroundColor Yellow
    Write-Host "Continuing anyway..." -ForegroundColor Gray
} else {
    Write-Host "  Drivers injected successfully" -ForegroundColor Green
}
Write-Host ""

Write-Host "Step 3: Unmounting and saving WinPE image..." -ForegroundColor Yellow
Dism /Unmount-Wim /MountDir:$MountPath /Commit
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to unmount WinPE image" -ForegroundColor Red
    Write-Host "Attempting to discard changes..." -ForegroundColor Yellow
    Dism /Unmount-Wim /MountDir:$MountPath /Discard
    exit 1
}
Write-Host "  WinPE image saved with drivers" -ForegroundColor Green
Write-Host ""

Write-Host "================================================" -ForegroundColor Green
Write-Host "SUCCESS! Network drivers added to WinPE" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next step: Rebuild your USB sticks with:" -ForegroundColor Yellow
Write-Host "  .\create-usb-simple.ps1 -DiskNumber 1 -DriveLetter D" -ForegroundColor White
Write-Host ""
Write-Host "Your Lenovo systems should now get network connectivity!" -ForegroundColor Green
Write-Host ""
