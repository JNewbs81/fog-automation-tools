# Simple Hybrid WinPE USB Creator
# Uses ADK's MakeWinPEMedia for proper hybrid boot support

param(
    [Parameter(Mandatory=$true)]
    [string]$USBDriveLetter
)

$ErrorActionPreference = "Stop"
$USBDriveLetter = $USBDriveLetter.TrimEnd(':')

Write-Host ""
Write-Host "=== Hybrid WinPE USB Creator ===" -ForegroundColor Cyan
Write-Host ""

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupWim = "$env:TEMP\boot_backup.wim"
$workDir = "C:\WinPE_amd64_work"

# Find Deployment Tools
$deployEnv = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\DandISetEnv.bat"
if (-not (Test-Path $deployEnv)) {
    Write-Host "ERROR: Windows ADK not found!" -ForegroundColor Red
    Write-Host "Install Windows ADK and WinPE add-on first." -ForegroundColor Yellow
    exit 1
}

# Step 1: Backup existing customized boot.wim
Write-Host "Step 1: Backing up your customized WinPE image..." -ForegroundColor Yellow
if (Test-Path "${USBDriveLetter}:\sources\boot.wim") {
    Copy-Item "${USBDriveLetter}:\sources\boot.wim" $backupWim -Force
    Write-Host "  Backup saved to: $backupWim" -ForegroundColor Green
} else {
    Write-Host "  ERROR: No boot.wim found on ${USBDriveLetter}:" -ForegroundColor Red
    exit 1
}

# Step 2: Clean up any previous work directory
Write-Host ""
Write-Host "Step 2: Preparing work directory..." -ForegroundColor Yellow
if (Test-Path $workDir) {
    Remove-Item $workDir -Recurse -Force
}

# Step 3: Run copype and MakeWinPEMedia from Deployment Tools command prompt
Write-Host ""
Write-Host "Step 3: Creating hybrid bootable USB..." -ForegroundColor Yellow
Write-Host "  This will FORMAT the USB drive!" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type 'YES' to continue"
if ($confirm -ne 'YES') {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 1
}

# Create a batch file to run in the Deployment Tools environment
$batchFile = "$env:TEMP\make_winpe.bat"
@"
@echo off
call "$deployEnv"
echo Creating WinPE working directory...
call copype amd64 $workDir
if errorlevel 1 (
    echo ERROR: copype failed
    exit /b 1
)
echo Creating bootable USB...
call MakeWinPEMedia /UFD $workDir ${USBDriveLetter}:
if errorlevel 1 (
    echo ERROR: MakeWinPEMedia failed
    exit /b 1
)
echo Done!
"@ | Out-File $batchFile -Encoding ASCII

# Run the batch file
Write-Host ""
Write-Host "Running ADK tools (this may take a few minutes)..." -ForegroundColor Cyan
$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batchFile`"" -Wait -PassThru -NoNewWindow
Remove-Item $batchFile -Force

if ($process.ExitCode -ne 0) {
    Write-Host "ERROR: Failed to create bootable USB" -ForegroundColor Red
    exit 1
}

# Step 4: Replace stock boot.wim with our customized one
Write-Host ""
Write-Host "Step 4: Restoring your customized WinPE image..." -ForegroundColor Yellow
Copy-Item $backupWim "${USBDriveLetter}:\sources\boot.wim" -Force
Write-Host "  Custom boot.wim restored." -ForegroundColor Green

# Step 5: Copy bios-tools to USB root (for easy access)
Write-Host ""
Write-Host "Step 5: Copying BIOS tools to USB..." -ForegroundColor Yellow
$biosTools = "$scriptDir\bios-tools"
if (Test-Path $biosTools) {
    Copy-Item $biosTools "${USBDriveLetter}:\bios-tools" -Recurse -Force
    Write-Host "  BIOS tools copied to USB root." -ForegroundColor Green
}

# Cleanup
Write-Host ""
Write-Host "Step 6: Cleaning up..." -ForegroundColor Yellow
Remove-Item $backupWim -Force -ErrorAction SilentlyContinue
if (Test-Path $workDir) {
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "  Cleanup complete." -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Hybrid USB Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your USB (${USBDriveLetter}:) now boots in:" -ForegroundColor White
Write-Host "  - Legacy BIOS mode (auto)" -ForegroundColor White
Write-Host "  - UEFI mode 64-bit (auto)" -ForegroundColor White
Write-Host ""
Write-Host "All your customizations (CCTK, WMI, etc.) are preserved." -ForegroundColor Cyan
