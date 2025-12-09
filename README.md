# Custom FOG Server Tools

Automation tools for FOG (Free Open-source Ghost) imaging server to reduce manual intervention and speed up mass PC deployment.

## Overview

This project provides two main sets of tools:

1. **BIOS Configuration Scripts** - Automatically configure Dell, HP, and Lenovo BIOS settings (disable Secure Boot, enable PXE, etc.)
2. **FOG Auto-Registration** - Automatically approve pending hosts and pre-stage hosts from CSV

## The Problem

Mass imaging PCs with FOG requires too much manual work:
- Must enter BIOS on every PC to disable Secure Boot
- Must set PXE boot order manually
- Must change SATA mode from RAID to AHCI (Dell)
- Must approve each pending host in FOG web UI
- Limited by physical KVM switch ports

## The Solution

### BIOS Automation

Boot from USB/WinPE → Script auto-detects manufacturer → Configures BIOS → Reboots → PXE boots to FOG

Supports:
- **Dell** (Command Configure / CCTK)
- **HP** (BIOS Configuration Utility)
- **Lenovo** (Think BIOS Config Tool)

### FOG Auto-Registration

- Cron job automatically approves pending hosts
- Renames hosts from MAC address to serial number
- Assigns default image and group
- CSV import for pre-staging known serial numbers

## Quick Start

### 1. BIOS Tools

```powershell
# Copy bios-tools folder to USB drive
Copy-Item -Recurse bios-tools\ E:\

# Download vendor tools (not included):
# - Dell: cctk.exe from Dell Command Configure
# - HP: BiosConfigUtility64.exe from HP BCU
# - Lenovo: SRSETUPWIN64.exe from Think BIOS Config Tool
```

Boot target PC from USB, run:
```batch
E:\bios-tools\auto-detect-apply.bat
```

### 2. FOG Auto-Registration

```bash
# Copy to FOG server
scp -r fog-customizations/auto-register/ fog@192.168.1.211:/tmp/

# Install on FOG server
ssh fog@192.168.1.211
sudo bash /tmp/auto-register/enable-auto-register.sh
```

## Directory Structure

```
Custom FOG Server/
├── README.md                    # This file
├── bios-tools/                  # BIOS configuration scripts
│   ├── auto-detect-apply.bat   # Auto-detect vendor and apply
│   ├── dell/                   # Dell CCTK scripts
│   ├── hp/                     # HP BCU scripts
│   └── lenovo/                 # Lenovo SRSETUP scripts
└── fog-customizations/         # FOG server modifications
    └── auto-register/          # Auto-registration tools
        ├── auto-approve-hosts.php
        ├── csv-import-hosts.php
        └── enable-auto-register.sh
```

## Workflow

### Before (Old Way)
1. Connect PC to KVM
2. Power on, mash F2/F10/F12
3. Navigate BIOS menus
4. Disable Secure Boot
5. Enable PXE boot
6. Change SATA to AHCI
7. Save and exit
8. Wait for PXE boot
9. Register in FOG
10. Go to web UI, approve host
11. Assign image
12. Start imaging
13. **Repeat 468 times** 😫

### After (New Way)
1. Boot PC from USB
2. `auto-detect-apply.bat` runs
3. BIOS configured automatically
4. PC reboots to PXE
5. Registers with FOG
6. Auto-approved (cron)
7. Imaging starts
8. Label prints
9. **Next PC!** 🚀

## Compatible Hardware

Tested with:
- Dell OptiPlex 3050
- Dell Precision 5820 Tower
- HP EliteDesk 705 G4 DM

Should work with most Dell, HP, and Lenovo business-class PCs.

## Requirements

- FOG Server 1.5.x (tested with 1.5.10)
- Windows ADK (for WinPE boot media)
- Vendor BIOS tools (free downloads, links in READMEs)

## License

These tools are provided as-is for use with FOG Project. FOG Project is licensed under GPLv3.

## Links

- [FOG Project](https://fogproject.org/)
- [FOG GitHub](https://github.com/FOGProject/fogproject)
- [Dell Command Configure](https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure)
- [HP BIOS Configuration Utility](https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html)
- [Lenovo Think BIOS Config Tool](https://support.lenovo.com/solutions/ht100612)

