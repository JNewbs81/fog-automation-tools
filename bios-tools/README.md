# BIOS Configuration Tools for FOG Imaging

Automated BIOS configuration scripts for Dell, HP, and Lenovo systems to prepare them for PXE imaging with FOG.

## What This Does

These scripts automatically configure BIOS settings required for FOG imaging:

| Setting | Dell | HP | Lenovo |
|---------|------|----|----|
| Disable Secure Boot | ✓ | ✓ | ✓ |
| Enable IPv4 PXE Boot | ✓ | ✓ | ✓ |
| Set SATA to AHCI | ✓ | - | - |
| Enable Wake on LAN | ✓ | ✓ | ✓ |
| Set NIC as first boot | ✓ | ✓ | ✓ |

## Quick Start

### Option 1: Auto-Detect (Recommended)

Run `auto-detect-apply.bat` - it will detect the manufacturer and run the appropriate script.

```batch
auto-detect-apply.bat
```

### Option 2: Run Vendor-Specific Script

```batch
dell\apply-dell-bios.bat
hp\apply-hp-bios.bat
lenovo\apply-lenovo-bios.bat
```

## Required Tools

You must download the vendor BIOS tools and place them in the appropriate folders:

### Dell
- **Dell Command Configure (CCTK)**
- Download: https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure
- Place `cctk.exe` in `dell\` folder

### HP
- **HP BIOS Configuration Utility (BCU)**
- Download: https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html
- Place `BiosConfigUtility64.exe` in `hp\` folder

### Lenovo
- **Think BIOS Config Tool (SRSETUP)**
- Download: https://support.lenovo.com/solutions/ht100612
- Place `SRSETUPWIN64.exe` in `lenovo\` folder

## Creating Bootable USB

### Method 1: Rufus + WinPE

1. Download Windows ADK and create WinPE media
2. Copy `bios-tools\` folder to WinPE USB
3. Add to `startnet.cmd`:
   ```batch
   X:\bios-tools\auto-detect-apply.bat
   ```

### Method 2: Simple DOS/Windows USB

1. Create bootable Windows USB with Rufus
2. Copy `bios-tools\` folder to USB root
3. Boot from USB, open command prompt
4. Run: `D:\bios-tools\auto-detect-apply.bat`

### Method 3: Integration with FOG

Copy tools to FOG server and access via network:
```batch
net use Z: \\192.168.1.211\bios-tools /user:fog password
Z:\auto-detect-apply.bat
```

## Directory Structure

```
bios-tools/
├── README.md                 # This file
├── auto-detect-apply.bat     # Auto-detect vendor and apply
├── dell/
│   ├── apply-dell-bios.bat   # Dell configuration script
│   ├── README.md             # Dell-specific docs
│   └── cctk.exe              # (you provide) Dell CCTK tool
├── hp/
│   ├── apply-hp-bios.bat     # HP configuration script
│   ├── fog-config.REPSET     # HP REPSET config file
│   ├── README.md             # HP-specific docs
│   └── BiosConfigUtility64.exe  # (you provide) HP BCU tool
└── lenovo/
    ├── apply-lenovo-bios.bat # Lenovo configuration script
    ├── fog-config.ini        # Lenovo INI config file
    ├── README.md             # Lenovo-specific docs
    └── SRSETUPWIN64.exe      # (you provide) Lenovo SRSETUP tool
```

## BIOS Passwords

If your systems have BIOS passwords set:

1. Create `bios_password.txt` in the vendor folder
2. Put the password on the first line (no newline at end)
3. The scripts will automatically use it

For HP, you can also create an encrypted password file:
```batch
BiosConfigUtility64.exe /npwdfile:"bios_password.bin"
```

## Workflow

### Before (Manual)
1. Connect PC to KVM
2. Boot PC, press F2/F10/F1 to enter BIOS
3. Navigate menus, disable Secure Boot
4. Enable PXE boot, change boot order
5. Change SATA mode (Dell)
6. Save and exit
7. Wait for PXE boot to FOG
8. **Repeat for every PC** ❌

### After (Automated)
1. Boot PC from USB (or Windows)
2. Run: `auto-detect-apply.bat`
3. Script configures everything and reboots
4. PC boots to FOG via PXE ✓
5. **Much faster!** ✓

## Troubleshooting

### "Tool not found"
- Download the vendor tool from the links above
- Place the .exe file in the correct vendor folder

### Settings don't apply
- Check if BIOS password is required
- Some settings have different names on different models
- Run the export command to see exact setting names

### System doesn't PXE boot after configuration
- Ensure network cable is connected
- Check DHCP server is configured for PXE
- Verify FOG server is running
- Some systems need a reboot for settings to take effect

## Integration with FOG Server

These tools can be deployed via FOG Snapins for existing Windows installations:

1. Zip the `bios-tools` folder
2. Create a Snapin in FOG with the zip
3. Set command: `cmd /c %SNAPINDIR%\auto-detect-apply.bat`
4. Deploy to hosts that need BIOS reconfiguration

## Support

- Dell CCTK docs: https://www.dell.com/support/manuals/en-us/command-configure-v4.2
- HP BCU docs: https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/HP_BCU_User_Guide.pdf
- Lenovo SRSETUP docs: https://docs.lenovo.com/bundle/ThinkCentre_Tiny_M70q_Gen_4_v1.0_Deployment_Guide/page/bios-config-tool.html

