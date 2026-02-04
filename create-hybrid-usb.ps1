# Create Hybrid UEFI/Legacy Bootable WinPE USB
# This USB will automatically boot in the correct mode based on BIOS setting

param(
    [Parameter(Mandatory=$true)]
    [string]$USBDriveLetter,
    
    [Parameter(Mandatory=$false)]
    [string]$ExistingBootWim = ""
)

$ErrorActionPreference = "Stop"

# Remove colon if provided
$USBDriveLetter = $USBDriveLetter.TrimEnd(':')

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Hybrid WinPE USB Creator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verify drive exists and is removable
$drive = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "${USBDriveLetter}:" }
if (-not $drive) {
    Write-Host "ERROR: Drive ${USBDriveLetter}: not found!" -ForegroundColor Red
    exit 1
}

if ($drive.DriveType -ne 2) {
    Write-Host "WARNING: Drive ${USBDriveLetter}: may not be a removable drive (DriveType=$($drive.DriveType))" -ForegroundColor Yellow
    $confirm = Read-Host "Continue anyway? (Y/N)"
    if ($confirm -ne 'Y') { exit 1 }
}

# Find Windows ADK
$adkPaths = @(
    "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment",
    "C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
)

$adkWinPE = $null
foreach ($path in $adkPaths) {
    if (Test-Path $path) {
        $adkWinPE = $path
        break
    }
}

if (-not $adkWinPE) {
    Write-Host "ERROR: Windows ADK WinPE add-on not found!" -ForegroundColor Red
    Write-Host "Please install Windows ADK and WinPE add-on first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found ADK WinPE at: $adkWinPE" -ForegroundColor Green

$adkRoot = Split-Path (Split-Path $adkWinPE -Parent) -Parent
$deployTools = "$adkRoot\Deployment Tools"
$bootSect = "$deployTools\amd64\Bcdboot\bootsect.exe"
$bcdboot = "bcdboot.exe"  

# Check for bootsect
if (-not (Test-Path $bootSect)) {
    # Try alternate location
    $bootSect = "$deployTools\amd64\bootsect.exe"
    if (-not (Test-Path $bootSect)) {
        Write-Host "WARNING: bootsect.exe not found at expected location" -ForegroundColor Yellow
        Write-Host "Legacy boot may not work properly" -ForegroundColor Yellow
        $bootSect = $null
    }
}

# Backup existing boot.wim if present and no custom one specified
$backupWim = "$env:TEMP\boot_backup.wim"
if (-not $ExistingBootWim -and (Test-Path "${USBDriveLetter}:\sources\boot.wim")) {
    Write-Host ""
    Write-Host "Found existing boot.wim on USB. Backing up..." -ForegroundColor Yellow
    Copy-Item "${USBDriveLetter}:\sources\boot.wim" $backupWim -Force
    $ExistingBootWim = $backupWim
    Write-Host "Backup saved to: $backupWim" -ForegroundColor Green
}

# Get disk number for the USB
$diskNumber = $null
$volumes = Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter -eq "${USBDriveLetter}:" }
if ($volumes) {
    # Get the disk number from the partition
    $partitions = Get-WmiObject -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='${USBDriveLetter}:'} WHERE AssocClass=Win32_LogicalDiskToPartition"
    if ($partitions) {
        foreach ($part in $partitions) {
            if ($part.DeviceID -match "Disk #(\d+)") {
                $diskNumber = $Matches[1]
            }
        }
    }
}

if (-not $diskNumber) {
    Write-Host ""
    Write-Host "Could not auto-detect disk number. Please check Disk Management." -ForegroundColor Yellow
    Write-Host ""
    
    # Show available disks
    Write-Host "Running diskpart to show disks..." -ForegroundColor Cyan
    $diskpartScript = "$env:TEMP\list_disks.txt"
    "list disk" | Out-File $diskpartScript -Encoding ASCII
    diskpart /s $diskpartScript
    Remove-Item $diskpartScript -Force
    
    Write-Host ""
    $diskNumber = Read-Host "Enter the disk number for USB drive ${USBDriveLetter}:"
}

Write-Host ""
Write-Host "WARNING: This will ERASE ALL DATA on Disk $diskNumber (${USBDriveLetter}:)!" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type 'YES' to continue"
if ($confirm -ne 'YES') {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Step 1: Formatting USB as MBR with FAT32 (hybrid compatible)..." -ForegroundColor Cyan

# Create diskpart script for MBR + FAT32 (works for both Legacy and UEFI)
$diskpartScript = "$env:TEMP\format_usb.txt"
@"
select disk $diskNumber
clean
create partition primary
select partition 1
active
format fs=fat32 quick label="WINPE"
assign letter=$USBDriveLetter
"@ | Out-File $diskpartScript -Encoding ASCII

diskpart /s $diskpartScript
Remove-Item $diskpartScript -Force

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Step 2: Copying WinPE boot files..." -ForegroundColor Cyan

# Create directory structure
$usbRoot = "${USBDriveLetter}:"
New-Item -Path "$usbRoot\sources" -ItemType Directory -Force | Out-Null
New-Item -Path "$usbRoot\boot" -ItemType Directory -Force | Out-Null
New-Item -Path "$usbRoot\EFI\Boot" -ItemType Directory -Force | Out-Null
New-Item -Path "$usbRoot\EFI\Microsoft\Boot" -ItemType Directory -Force | Out-Null

# Copy base WinPE files from ADK
$winpeAmd64 = "$adkWinPE\amd64"
$winpeMedia = "$winpeAmd64\Media"
$winpeFWFiles = "$adkWinPE\amd64\Media\EFI\Boot"

# Copy boot.wim (either custom or from ADK)
if ($ExistingBootWim -and (Test-Path $ExistingBootWim)) {
    Write-Host "Using existing customized boot.wim..." -ForegroundColor Green
    Copy-Item $ExistingBootWim "$usbRoot\sources\boot.wim" -Force
} else {
    Write-Host "Using stock ADK boot.wim..." -ForegroundColor Yellow
    Copy-Item "$winpeAmd64\en-us\winpe.wim" "$usbRoot\sources\boot.wim" -Force
}

# Copy UEFI boot files
Write-Host "Copying UEFI boot files..." -ForegroundColor White
if (Test-Path "$winpeFWFiles\bootx64.efi") {
    Copy-Item "$winpeFWFiles\bootx64.efi" "$usbRoot\EFI\Boot\bootx64.efi" -Force
} elseif (Test-Path "$winpeMedia\EFI\Boot\bootx64.efi") {
    Copy-Item "$winpeMedia\EFI\Boot\bootx64.efi" "$usbRoot\EFI\Boot\bootx64.efi" -Force
} else {
    # Try to extract from boot.wim
    Write-Host "Extracting bootx64.efi from boot.wim..." -ForegroundColor Yellow
    $mountDir = "C:\WinPE_Temp_Mount"
    New-Item -Path $mountDir -ItemType Directory -Force | Out-Null
    dism /Mount-Wim /WimFile:"$usbRoot\sources\boot.wim" /Index:1 /MountDir:$mountDir /ReadOnly
    if (Test-Path "$mountDir\Windows\Boot\EFI\bootmgfw.efi") {
        Copy-Item "$mountDir\Windows\Boot\EFI\bootmgfw.efi" "$usbRoot\EFI\Boot\bootx64.efi" -Force
    }
    dism /Unmount-Wim /MountDir:$mountDir /Discard
    Remove-Item $mountDir -Force -Recurse -ErrorAction SilentlyContinue
}

# Copy Legacy boot files
Write-Host "Copying Legacy boot files..." -ForegroundColor White
if (Test-Path "$winpeMedia\bootmgr") {
    Copy-Item "$winpeMedia\bootmgr" "$usbRoot\bootmgr" -Force
}
if (Test-Path "$winpeMedia\bootmgr.efi") {
    Copy-Item "$winpeMedia\bootmgr.efi" "$usbRoot\bootmgr.efi" -Force
}
if (Test-Path "$winpeMedia\boot\bcd") {
    Copy-Item "$winpeMedia\boot\*" "$usbRoot\boot\" -Recurse -Force
}
if (Test-Path "$winpeMedia\boot\boot.sdi") {
    Copy-Item "$winpeMedia\boot\boot.sdi" "$usbRoot\boot\boot.sdi" -Force
}

# Apply boot sector for Legacy boot
if ($bootSect) {
    Write-Host ""
    Write-Host "Step 3: Writing MBR boot sector for Legacy boot..." -ForegroundColor Cyan
    & $bootSect /nt60 ${USBDriveLetter}: /mbr
}

# Create BCD stores for both boot methods
Write-Host ""
Write-Host "Step 4: Creating boot configuration..." -ForegroundColor Cyan

# Use bcdboot to set up boot files properly
$mountDir = "C:\WinPE_Temp_Mount2"
New-Item -Path $mountDir -ItemType Directory -Force | Out-Null
dism /Mount-Wim /WimFile:"$usbRoot\sources\boot.wim" /Index:1 /MountDir:$mountDir /ReadOnly

# Create BIOS boot config
bcdboot "$mountDir\Windows" /s ${USBDriveLetter}: /f BIOS
# Create UEFI boot config  
bcdboot "$mountDir\Windows" /s ${USBDriveLetter}: /f UEFI

dism /Unmount-Wim /MountDir:$mountDir /Discard
Remove-Item $mountDir -Force -Recurse -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Step 5: Copying BIOS tools..." -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$biosTools = "$scriptDir\bios-tools"

if (Test-Path $biosTools) {
    Copy-Item $biosTools "$usbRoot\bios-tools" -Recurse -Force
    Write-Host "BIOS tools copied successfully." -ForegroundColor Green
} else {
    Write-Host "WARNING: bios-tools folder not found at $biosTools" -ForegroundColor Yellow
}

# Copy startnet.cmd if exists
$startnetSrc = "$scriptDir\startnet.cmd"
if (Test-Path $startnetSrc) {
    # Need to mount and copy startnet.cmd
    Write-Host "Updating startnet.cmd in boot.wim..." -ForegroundColor Cyan
    $mountDir = "C:\WinPE_Mount"
    if (-not (Test-Path $mountDir)) {
        New-Item -Path $mountDir -ItemType Directory -Force | Out-Null
    }
    dism /Mount-Wim /WimFile:"$usbRoot\sources\boot.wim" /Index:1 /MountDir:$mountDir
    Copy-Item $startnetSrc "$mountDir\Windows\System32\startnet.cmd" -Force
    
    # Also ensure bios-tools is in the WIM
    if (Test-Path $biosTools) {
        Copy-Item $biosTools "$mountDir\bios-tools" -Recurse -Force
    }
    
    dism /Unmount-Wim /MountDir:$mountDir /Commit
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Hybrid USB Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The USB drive ${USBDriveLetter}: is now bootable in both:" -ForegroundColor White
Write-Host "  - Legacy BIOS mode" -ForegroundColor White
Write-Host "  - UEFI mode (64-bit)" -ForegroundColor White
Write-Host ""
Write-Host "The system will automatically use the correct boot method." -ForegroundColor Cyan

# Cleanup backup if we created it
if ($backupWim -eq $ExistingBootWim -and (Test-Path $backupWim)) {
    Remove-Item $backupWim -Force -ErrorAction SilentlyContinue
}
