# Lenovo BIOS Configuration for FOG Imaging

## Overview

This script uses Lenovo Think BIOS Config Tool to automatically configure BIOS settings for PXE imaging with FOG.

## Settings Applied

- **Secure Boot**: Disabled
- **Ethernet LAN Option ROM**: Enabled
- **IPv4 PXE Boot**: Enabled
- **Network Boot**: Enabled
- **Boot Mode**: UEFI Only
- **Wake on LAN**: Enabled
- **Fast Boot**: Disabled (for reliable PXE)

## Requirements

1. **Lenovo Think BIOS Config Tool** - Download from Lenovo Support:
   - https://support.lenovo.com/solutions/ht100612
   - Look for "Think BIOS Config Tool" or "SRSETUP"
   - Extract and place `SRSETUPWIN64.exe` in this folder

2. **Run from WinPE or Windows** - Must run with admin privileges

## Supported Models

Works on most Lenovo business-class systems:
- ThinkCentre (M Series, etc.)
- ThinkPad (T, X, L, E Series)
- ThinkStation (P Series)

## Files Included

- `apply-lenovo-bios.bat` - Main script to apply settings
- `fog-config.ini` - INI configuration file with all settings

## Usage

### From Windows (Admin Command Prompt)

```batch
apply-lenovo-bios.bat
```

### From WinPE

1. Copy this folder to USB or network share
2. Boot to WinPE
3. Navigate to this folder
4. Run: `apply-lenovo-bios.bat`

### If BIOS Password is Set

Create a file named `bios_password.txt` in this folder containing your BIOS supervisor password.

## Command Reference

### Export current BIOS settings
```batch
SRSETUPWIN64.exe /export:"current_config.ini"
```

### Apply settings from INI file
```batch
SRSETUPWIN64.exe /config:"fog-config.ini"
```

### Set individual setting
```batch
SRSETUPWIN64.exe /set:SecureBoot,Disabled
```

### Set with password
```batch
SRSETUPWIN64.exe /set:SecureBoot,Disabled,pass:YourPassword
```

## INI File Format

Lenovo INI files use the format:
```
SettingName,Value
```

Multiple formats may work:
- `SecureBoot,Disabled`
- `Secure Boot,Disabled`

The script tries multiple variations to handle different model naming conventions.

## Troubleshooting

### "SRSETUP not found"
- Download Think BIOS Config Tool from Lenovo Support
- Place `SRSETUPWIN64.exe` in this folder

### Settings don't apply
- Check if supervisor password is required
- Export current config to see exact setting names for your model
- Some settings may have different names on different models

### Return codes
- 0: Success
- 1: Error/Not supported
- 2: Invalid parameter
- 3: Access denied (password required)

## Model-Specific Notes

### ThinkCentre M Series
Setting names typically use no spaces: `SecureBoot`, `NetworkBoot`

### ThinkPad
Setting names often include spaces: `Secure Boot`, `Network Boot`

### ThinkStation
Similar to ThinkCentre, uses no-space format

## Manual Verification

After running, verify settings in BIOS:
1. Reboot and press F1 (ThinkPad) or Enter→F1 (ThinkCentre) to enter BIOS
2. Check: Security → Secure Boot → Disabled
3. Check: Startup → Network Boot → Enabled
4. Check: Startup → Boot Priority Order → Network first

