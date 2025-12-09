# Dell BIOS Configuration for FOG Imaging

## Overview

This script uses Dell Command Configure (CCTK) to automatically configure BIOS settings for PXE imaging with FOG.

## Settings Applied

- **Secure Boot**: Disabled
- **Embedded NIC**: Enabled
- **IPv4 PXE Boot**: Enabled
- **SATA Operation**: AHCI (not RAID)
- **Boot Order**: NIC first
- **UEFI Network Stack**: Enabled

## Requirements

1. **Dell Command Configure** - Download from Dell Support:
   - https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure
   - Extract and place `cctk.exe` in this folder, or install to default location

2. **Run from WinPE or Windows** - Must run with admin privileges

## Supported Models

Tested on:
- Dell OptiPlex 3050
- Dell Precision 5820 Tower

Should work on most Dell business-class systems (OptiPlex, Precision, Latitude, etc.)

## Usage

### From Windows (Admin Command Prompt)

```batch
apply-dell-bios.bat
```

### From WinPE

1. Copy this folder to USB or network share
2. Boot to WinPE
3. Navigate to this folder
4. Run: `apply-dell-bios.bat`

### If BIOS Password is Set

Create a file named `bios_password.txt` in this folder containing your BIOS password (no newline at end).

## Troubleshooting

### "CCTK not found"
- Download Dell Command Configure from Dell Support
- Place `cctk.exe` in this folder, or install to default location

### "Access denied" or settings don't apply
- Ensure running as Administrator
- Check if BIOS password is required
- Some settings may require reboot to take effect

### SATA mode change warning
Changing from RAID to AHCI may cause Windows to fail to boot if it was installed in RAID mode. This is expected - after FOG imaging with a fresh Windows install, AHCI will work correctly.

## Manual Verification

After running, verify settings in BIOS:
1. Reboot and press F2 to enter BIOS Setup
2. Check: Secure Boot → Disabled
3. Check: SATA Operation → AHCI
4. Check: Boot Sequence → Onboard NIC first

