#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Simple USB creator for WinPE FOG
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$DiskNumber,
    [string]$DriveLetter = "D"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "FOG BIOS Config - Simple USB Creator" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Verify WinPE media exists
$MediaPath = "C:\WinPE_FOG\media"
if (-not (Test-Path $MediaPath)) {
    Write-Host "ERROR: WinPE media not found at $MediaPath" -ForegroundColor Red
    Write-Host "Please run create-winpe-usb.ps1 first to prepare the WinPE image." -ForegroundColor Red
    exit 1
}

# Verify disk exists
$disk = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
if (-not $disk) {
    Write-Host "ERROR: Disk $DiskNumber not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available disks:" -ForegroundColor Yellow
    Get-Disk | Format-Table Number, FriendlyName, BusType, Size -AutoSize
    exit 1
}

Write-Host "Target Disk: $($disk.FriendlyName) (Disk $DiskNumber)" -ForegroundColor Cyan
Write-Host "Size: $([math]::Round($disk.Size / 1GB, 2)) GB" -ForegroundColor Cyan
Write-Host ""
Write-Host "WARNING: This will ERASE ALL DATA on Disk $DiskNumber" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type 'YES' to continue"
if ($confirm -ne "YES") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Step 1: Cleaning and formatting disk..." -ForegroundColor Yellow

# Create diskpart script
$diskpartScript = @"
select disk $DiskNumber
clean
create partition primary
select partition 1
active
format fs=fat32 quick label="WINPE_FOG"
assign letter=$DriveLetter
exit
"@

$scriptPath = "$env:TEMP\diskpart_usb_simple.txt"
Set-Content -Path $scriptPath -Value $diskpartScript -Force

diskpart /s $scriptPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: diskpart failed" -ForegroundColor Red
    exit 1
}

Write-Host "  Disk formatted successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Step 2: Copying WinPE files to USB..." -ForegroundColor Yellow

# Wait for drive to be ready
Start-Sleep -Seconds 3

# Verify drive letter exists
if (-not (Test-Path "${DriveLetter}:\")) {
    Write-Host "ERROR: Drive ${DriveLetter}: not accessible after format" -ForegroundColor Red
    exit 1
}

# Copy files using robocopy for better reliability
robocopy "$MediaPath" "${DriveLetter}:\" /E /R:3 /W:1 /NFL /NDL /NP

if ($LASTEXITCODE -le 7) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "SUCCESS! Bootable USB created!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your USB is ready at ${DriveLetter}:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To verify, check for:" -ForegroundColor White
    Write-Host "  - ${DriveLetter}:\Boot folder" -ForegroundColor White
    Write-Host "  - ${DriveLetter}:\sources\boot.wim" -ForegroundColor White
    Write-Host ""
    Write-Host "To use:" -ForegroundColor Yellow
    Write-Host "  1. Insert USB into target PC" -ForegroundColor White
    Write-Host "  2. Boot from USB" -ForegroundColor White
    Write-Host "  3. BIOS configures automatically" -ForegroundColor White
    Write-Host "  4. PC reboots to PXE -> FOG" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "ERROR: Failed to copy files (robocopy exit code: $LASTEXITCODE)" -ForegroundColor Red
}
