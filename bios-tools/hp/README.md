# HP BIOS Configuration for FOG Imaging

## Overview

This script uses HP BIOS Configuration Utility (BCU) to automatically configure BIOS settings for PXE imaging with FOG.

## Settings Applied

- **Secure Boot**: Disabled (with Legacy Support enabled)
- **Network/PXE Boot**: Enabled
- **IPv4 PXE**: Enabled
- **Boot Order**: Network adapter first
- **Fast Boot**: Disabled (for reliable PXE)
- **Wake on LAN**: Enabled
- **S5 Wake on LAN**: Enabled

## Requirements

1. **HP BIOS Configuration Utility** - Download from HP:
   - https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html
   - Extract and place `BiosConfigUtility64.exe` in this folder

2. **Run from WinPE or Windows** - Must run with admin privileges

## Supported Models

Tested on:
- HP EliteDesk 705 G4 DM

Should work on most HP business-class systems (EliteDesk, ProDesk, EliteBook, ProBook, ZBook, etc.)

## Files Included

- `apply-hp-bios.bat` - Main script to apply settings
- `fog-config.REPSET` - HP REPSET configuration file with all settings

## Usage

### From Windows (Admin Command Prompt)

```batch
apply-hp-bios.bat
```

### From WinPE

1. Copy this folder to USB or network share
2. Boot to WinPE
3. Navigate to this folder
4. Run: `apply-hp-bios.bat`

### If BIOS Password is Set

**Option 1**: Create `bios_password.txt` with plaintext password

**Option 2**: Create encrypted password file:
```batch
BiosConfigUtility64.exe /npwdfile:"bios_password.bin" /nspwdfile:"bios_password.bin"
```
Then enter your password when prompted.

## Exporting Current Settings

To see current BIOS configuration:
```batch
BiosConfigUtility64.exe /getconfig:"current_config.txt"
```

## Creating Custom REPSET Files

1. Configure BIOS manually on one machine
2. Export settings: `BiosConfigUtility64.exe /getconfig:"my_config.REPSET"`
3. Edit the file to mark desired settings with `*`
4. Use as template for other machines

## Troubleshooting

### "BCU not found"
- Download HP BIOS Configuration Utility from HP FTP
- Place `BiosConfigUtility64.exe` in this folder

### Settings don't apply
- Check if BIOS password is required
- Some settings may have different names on different models
- Export current config to see exact setting names for your model

### "Return code" errors
Common BCU return codes:
- 0: Success
- 1: Not supported on this system
- 2: Unknown error
- 3: Timeout
- 10: Setup password required
- 32: Password file error

## Manual Verification

After running, verify settings in BIOS:
1. Reboot and press F10 to enter BIOS Setup
2. Check: Security → Secure Boot Configuration → Disabled
3. Check: Advanced → Boot Options → Network Boot → Enabled
4. Check: Advanced → Boot Order → Network first

