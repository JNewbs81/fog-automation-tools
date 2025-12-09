# WinPE Integration Guide

This guide explains how to integrate the BIOS configuration tools into a WinPE boot environment for automated BIOS setup.

## Prerequisites

1. Windows ADK (Assessment and Deployment Kit)
2. Windows PE add-on for ADK
3. The vendor BIOS tools downloaded and placed in folders

## Creating WinPE with BIOS Tools

### Step 1: Install Windows ADK

Download and install:
- Windows ADK: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
- Windows PE add-on for ADK

### Step 2: Create WinPE Working Directory

Open "Deployment and Imaging Tools Environment" as Administrator:

```powershell
copype amd64 C:\WinPE_BIOS
```

### Step 3: Mount the WinPE Image

```powershell
Dism /Mount-Image /ImageFile:"C:\WinPE_BIOS\media\sources\boot.wim" /Index:1 /MountDir:"C:\WinPE_BIOS\mount"
```

### Step 4: Copy BIOS Tools

```powershell
# Create directory in WinPE
New-Item -ItemType Directory -Path "C:\WinPE_BIOS\mount\bios-tools" -Force

# Copy all BIOS tools
Copy-Item -Path ".\bios-tools\*" -Destination "C:\WinPE_BIOS\mount\bios-tools\" -Recurse
```

### Step 5: Modify Startup Script

Edit `C:\WinPE_BIOS\mount\Windows\System32\startnet.cmd`:

```batch
wpeinit
@echo off
echo.
echo =============================================
echo FOG BIOS Configuration - WinPE Boot
echo =============================================
echo.
echo This will configure BIOS settings for FOG imaging:
echo   - Disable Secure Boot
echo   - Enable IPv4 PXE Boot
echo   - Set SATA to AHCI (Dell only)
echo   - Set Network as first boot device
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul

X:\bios-tools\auto-detect-apply.bat
```

### Step 6: Unmount and Commit Changes

```powershell
Dism /Unmount-Image /MountDir:"C:\WinPE_BIOS\mount" /Commit
```

### Step 7: Create Bootable USB

```powershell
# Insert USB drive (will be formatted!)
# Find disk number with: Get-Disk

# Format and prepare USB (replace X with disk number)
MakeWinPEMedia /UFD C:\WinPE_BIOS E:
```

Or create ISO for CD/network boot:

```powershell
MakeWinPEMedia /ISO C:\WinPE_BIOS C:\WinPE_BIOS\FOG_BIOS_Config.iso
```

## Alternative: Simple Batch USB

If you don't need full WinPE, create a simple bootable USB:

### Step 1: Create Windows To Go or Install Media USB

Use Rufus to create a Windows installation USB.

### Step 2: Add BIOS Tools

Copy `bios-tools\` folder to USB root.

### Step 3: Boot and Run

1. Boot from USB
2. At Windows Setup, press Shift+F10 for command prompt
3. Navigate to USB: `D:` or `E:`
4. Run: `bios-tools\auto-detect-apply.bat`

## Network Boot Integration

### Serve BIOS Tools via SMB

On FOG server, create a share:

```bash
# Create share directory
sudo mkdir -p /srv/bios-tools
sudo cp -r /path/to/bios-tools/* /srv/bios-tools/

# Create Samba share (add to /etc/samba/smb.conf)
[bios-tools]
   path = /srv/bios-tools
   browseable = yes
   read only = yes
   guest ok = yes
```

### Access from WinPE

```batch
net use Z: \\192.168.1.211\bios-tools
Z:\auto-detect-apply.bat
net use Z: /delete
```

## Automated Workflow

### Full Automation startnet.cmd

```batch
wpeinit

@echo off
cls
echo =============================================
echo FOG Automated BIOS Configuration
echo =============================================
echo.

REM Get system info
for /f "tokens=2 delims==" %%a in ('wmic computersystem get manufacturer /value ^| find "="') do set "MAKE=%%a"
for /f "tokens=2 delims==" %%a in ('wmic computersystem get model /value ^| find "="') do set "MODEL=%%a"
for /f "tokens=2 delims==" %%a in ('wmic bios get serialnumber /value ^| find "="') do set "SERIAL=%%a"

echo System: %MAKE% %MODEL%
echo Serial: %SERIAL%
echo.

REM Run BIOS config
echo Configuring BIOS...
X:\bios-tools\auto-detect-apply.bat

echo.
echo BIOS configured. System will reboot to PXE in 5 seconds...
wpeutil reboot
```

## Testing

1. Boot a test system from the WinPE USB
2. Verify the script detects the correct manufacturer
3. Check that settings are applied (may show warnings for unsupported settings)
4. Confirm system reboots and PXE boots to FOG

## Troubleshooting

### "X:\bios-tools not found"
- Ensure files were copied before unmounting WinPE image
- Check the path in startnet.cmd matches where you copied files

### Vendor tool fails
- Ensure the .exe files are included (they're not in the git repo)
- Check the tool works on a normal Windows install first

### System won't boot from USB
- Check BIOS is set to boot from USB
- Try different USB port (USB 2.0 often more compatible)
- Ensure USB was created correctly with MakeWinPEMedia

