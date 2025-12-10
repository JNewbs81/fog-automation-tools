#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Manually creates bootable WinPE USB
#>

param(
    [string]$USBDriveLetter = "E"
)

$MediaPath = "C:\WinPE_FOG\media"

Write-Host "Creating bootable USB on ${USBDriveLetter}:..." -ForegroundColor Yellow
Write-Host ""
Write-Host "WARNING: This will ERASE ALL DATA on ${USBDriveLetter}:" -ForegroundColor Red
$confirm = Read-Host "Type 'YES' to continue"
if ($confirm -ne "YES") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit
}

# Get disk number for the USB drive
$usbVolume = Get-Volume -DriveLetter $USBDriveLetter -ErrorAction SilentlyContinue
if (-not $usbVolume) {
    Write-Host "ERROR: Drive ${USBDriveLetter}: not found" -ForegroundColor Red
    exit 1
}

$usbPartition = Get-Partition -DriveLetter $USBDriveLetter
$diskNumber = $usbPartition.DiskNumber

Write-Host ""
Write-Host "Found USB disk #$diskNumber" -ForegroundColor Cyan
Write-Host ""

# Create diskpart script
$diskpartScript = @"
select disk $diskNumber
clean
create partition primary
select partition 1
active
format fs=fat32 quick label="WINPE_FOG"
assign letter=$USBDriveLetter
"@

$scriptPath = "$env:TEMP\diskpart_usb.txt"
Set-Content -Path $scriptPath -Value $diskpartScript

Write-Host "Step 1: Formatting USB drive..." -ForegroundColor Yellow
diskpart /s $scriptPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: diskpart failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Copying WinPE files to USB..." -ForegroundColor Yellow
# Give Windows a moment to recognize the newly formatted drive
Start-Sleep -Seconds 2

xcopy "${MediaPath}\*" "${USBDriveLetter}:\" /E /H /F /Y

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "SUCCESS! Bootable USB created!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your USB is ready at ${USBDriveLetter}:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To use:" -ForegroundColor White
    Write-Host "  1. Insert USB into target PC" -ForegroundColor White
    Write-Host "  2. Boot from USB" -ForegroundColor White
    Write-Host "  3. BIOS configures automatically" -ForegroundColor White
    Write-Host "  4. PC reboots to PXE -> FOG" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "ERROR: Failed to copy files" -ForegroundColor Red
}

