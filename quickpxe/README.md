# QuickPXE - BIOS Configuration USB Tool

A Rufus-style desktop application for creating WinPE USB drives with BIOS configuration tools.

## Features

- **Create WinPE USB** - Build bootable USB drives from scratch using Windows ADK
- **Update Existing USB** - Update configs on existing USB without full rebuild
- **Extract BIOS Settings** - Export current PC's BIOS configuration with one click
- **Import Configurations** - Import and manage BIOS config files
- **Model-Specific Configs** - Automatically detects model and applies the right config
- **Download Tools** - Quick links to download Dell CCTK, HP BCU, and Lenovo tools

## Requirements

- Windows 10/11
- Administrator privileges
- Windows ADK with WinPE add-on (can be installed from the tool)

## Quick Start

1. **Run as Administrator**
   ```powershell
   # Right-click PowerShell -> Run as Administrator
   cd quickpxe
   .\QuickPXE.ps1
   ```

2. **Install Windows ADK** (if not already installed)
   - Click "Install ADK" button on the USB tab
   - Or use the download buttons on the Downloads tab

3. **Download BIOS Tools**
   - Go to Downloads tab
   - Download tools for your manufacturer(s)
   - Place them in the `tools/` folder

4. **Extract a BIOS Config** (optional)
   - Go to BIOS Configuration tab
   - Click "Extract Current BIOS"
   - This saves the current PC's settings as a template

5. **Create the USB**
   - Insert USB drive (8GB+ recommended)
   - Select the drive from dropdown
   - Click "Create WinPE USB"

## Folder Structure

```
quickpxe/
├── QuickPXE.ps1           # Main application
├── startnet-quickpxe.cmd  # WinPE startup script
├── lib/                   # PowerShell library functions
│   ├── USB-Functions.ps1
│   ├── ADK-Functions.ps1
│   ├── WinPE-Functions.ps1
│   └── BIOS-Functions.ps1
├── configs/               # BIOS configuration files
│   ├── dell/
│   │   ├── optiplex-7040.cctk    # Model-specific
│   │   └── default.cctk          # Fallback
│   ├── hp/
│   │   └── default.REPSET
│   └── lenovo/
│       └── default.ini
└── tools/                 # BIOS configuration tools
    ├── dell/
    │   └── cctk.exe
    ├── hp/
    │   └── BiosConfigUtility64.exe
    └── lenovo/
        └── ThinkBiosConfig.hta
```

## Configuration Priority

When the USB boots, it looks for configs in this order:

1. **Model-Specific** - `configs/dell/optiplex-7040.cctk`
2. **Series** - `configs/dell/optiplex.cctk` (first word of model)
3. **Default** - `configs/dell/default.cctk`

## Workflow

### Initial Setup
1. Run QuickPXE on a working PC
2. Extract the BIOS config you want to replicate
3. Set it as the default (or keep it model-specific)
4. Create a USB with your configs

### Deploying to New PCs
1. Boot the target PC from the USB
2. Script auto-detects manufacturer and model
3. Applies the appropriate BIOS config
4. Reboots for PXE imaging (or manual boot)

### Updating Configs
1. Make changes to files in `configs/` folder
2. Select USB drive in QuickPXE
3. Click "Update Existing USB"
4. Script mounts WIM, updates files, unmounts

## Supported Manufacturers

| Manufacturer | Tool | Config Extension |
|--------------|------|------------------|
| Dell | CCTK (Command Configure) | `.cctk` |
| HP | BCU (BIOS Configuration Utility) | `.REPSET` |
| Lenovo | ThinkBiosConfig | `.ini` |

## Download Links

- **Dell CCTK**: https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure
- **HP BCU**: https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html
- **Lenovo**: https://support.lenovo.com/solutions/ht100612
- **Windows ADK**: https://go.microsoft.com/fwlink/?linkid=2243390
- **WinPE Add-on**: https://go.microsoft.com/fwlink/?linkid=2243391

## Troubleshooting

### "No USB drives found"
- Make sure USB is plugged in
- Try a different USB port
- Click Refresh button

### "ADK Not Installed"
- Click "Install ADK" or download manually
- Requires internet connection
- Installation takes 10-20 minutes

### BIOS tool not found
- Download the tool for your manufacturer
- Place it in the correct `tools/` subfolder
- Check the README in `tools/` for exact filenames

### Config not applied
- Verify config file exists in `configs/` folder
- Check the model name matches (use Extract to see normalized name)
- Some settings require BIOS password - create password file if needed

## License

MIT License - Use freely for personal or commercial purposes.
