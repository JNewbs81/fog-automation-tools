# FOG BIOS Configuration Web Interface

A beautiful web-based tool to upload, edit, and manage BIOS configurations for Dell, HP, and Lenovo systems used with FOG imaging.

## Features

✅ **Upload existing BIOS configs** - Import configs from Dell CCTK, HP BCU, or Lenovo Think BIOS Config Tool  
✅ **Apply FOG settings** - Automatically configure for UEFI, PXE, disable Secure Boot, etc.  
✅ **Live preview** - See your configuration in real-time  
✅ **Download configs** - Save updated configs to use locally  
✅ **Upload to FOG server** - Push configs directly to your FOG server  
✅ **Beautiful UI** - Modern, responsive design that works on any device  

## Installation

### Option 1: Run Locally (Quick Test)

Just open `index.html` in your web browser! No server needed for basic functionality.

### Option 2: Host on FOG Server (Recommended)

1. **Upload files to FOG server:**

```powershell
cd C:\Cursor\USB\fog-automation-tools
scp -r web-interface fog@192.168.1.211:/tmp/
```

2. **SSH to FOG server and install:**

```bash
ssh fog@192.168.1.211
sudo mv /tmp/web-interface /var/www/html/fog-bios-config
sudo chown -R www-data:www-data /var/www/html/fog-bios-config
sudo chmod 755 /var/www/html/fog-bios-config
```

3. **Access the web interface:**

Open: `http://192.168.1.211/fog-bios-config/`

## How to Use

### 1. Get Your Current BIOS Config

**Dell Systems:**
```cmd
cd C:\Dell\cctk
cctk.exe --output=current-config.cctk
```

**HP Systems:**
```cmd
cd C:\HP\BCU
BiosConfigUtility64.exe /GetConfig:current-config.txt
```

**Lenovo Systems:**
- Open Think BIOS Config Tool
- Click "Get Settings"
- Save as .ini file

### 2. Upload to Web Interface

1. Open the web interface
2. Select your manufacturer tab (Dell/HP/Lenovo)
3. Click or drag your config file to upload
4. Review detected settings

### 3. Apply FOG Imaging Settings

Click "Apply Settings to Config" to automatically configure:
- ✅ Secure Boot: Disabled
- ✅ Boot Mode: UEFI Only
- ✅ Legacy/CSM: Disabled
- ✅ PXE Boot: Enabled
- ✅ UEFI Network Stack: Enabled
- ✅ SATA Mode: AHCI (Dell)
- ✅ Adapter Warnings: Disabled (Dell)

### 4. Download or Upload

**Download:**
- Click "Download Configuration File"
- Use the file with your vendor's BIOS tool

**Upload to FOG Server:**
- Click "Upload to FOG Server"
- Files are automatically placed in the correct location
- All USB sticks will use the updated config

## File Locations on FOG Server

After upload, files are saved to:

```
/var/www/html/fog-automation-tools/bios-tools/
├── dell/
│   └── fog-bios-config.cctk
├── hp/
│   └── fog-config.REPSET
└── lenovo/
    └── fog-config.ini
```

## Advanced Features

### Bulk Configuration

You can upload configs from multiple systems and combine the best settings:

1. Upload config from System A
2. Apply FOG settings
3. Download
4. Upload config from System B
5. Merge settings
6. Upload to FOG server

### Custom Settings

All settings are editable in the web interface:
- Secure Boot (Enabled/Disabled)
- Boot Mode (UEFI/Legacy/Both)
- CSM Support
- PXE Boot
- Wake on LAN
- SATA Mode
- And more...

## Troubleshooting

### Upload to server fails
- Make sure PHP is installed on your FOG server
- Check file permissions: `sudo chmod 755 /var/www/html/fog-bios-config`
- Check Apache error log: `sudo tail -f /var/log/apache2/error.log`

### Config not parsing correctly
- Make sure you exported the config using the vendor's official tool
- Check that the file extension matches (.cctk for Dell, .REPSET for HP, .ini for Lenovo)

### Can't download file
- Check your browser's download settings
- Try a different browser
- Make sure pop-ups are not blocked

## Security Notes

- This tool is intended for use on internal networks only
- The PHP upload script has basic security checks
- For production use, add authentication (htpasswd, etc.)
- Never expose this to the internet without proper security

## Tips

💡 **Save time:** Export a "golden" config from a properly configured system, upload it, and use it as a template  
💡 **Version control:** Download configs with timestamps in the filename for tracking  
💡 **Test first:** Always test a new config on ONE system before deploying to all  

## Support

For issues or questions, check the main project README or GitHub issues.
