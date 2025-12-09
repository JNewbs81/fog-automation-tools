# FOG Auto-Registration Tools

Tools to reduce manual intervention during FOG host registration.

## Overview

When a new PC boots to FOG for the first time, it registers as a "pending" host and requires manual approval in the FOG web interface. These tools automate that process.

## Components

### auto-approve-hosts.php

Automatically approves pending hosts with optional features:
- Auto-rename hosts from MAC address to serial number
- Assign a default image
- Add to a default group

### csv-import-hosts.php

Pre-stage hosts by importing from a CSV file:
- Import known serial numbers before imaging
- Pre-assign images and groups
- Speeds up deployment when you know what's coming

### enable-auto-register.sh

Bash script to install and configure everything:
- Configures FOG settings for quick registration
- Installs PHP scripts
- Sets up cron job for auto-approval

## Installation

### Quick Install (on FOG server)

```bash
# Copy files to FOG server
scp -r auto-register/ fog@192.168.1.211:/tmp/

# SSH to FOG server
ssh fog@192.168.1.211

# Run installer
sudo bash /tmp/auto-register/enable-auto-register.sh
```

### Manual Install

1. Copy scripts to FOG service directory:
```bash
sudo cp auto-approve-hosts.php /var/www/html/fog/service/
sudo cp csv-import-hosts.php /var/www/html/fog/service/
sudo chown www-data:www-data /var/www/html/fog/service/*.php
```

2. Edit configuration in `auto-approve-hosts.php`:
```php
$config = [
    'api_key' => 'YOUR_SECURE_KEY',  // For web access
    'default_image' => 'Windows11',   // Image to assign
    'default_group' => 'NewPCs',      // Group to add to
    'auto_rename' => true,            // Rename to serial
];
```

3. Set up cron job:
```bash
echo "*/5 * * * * www-data /usr/bin/php /var/www/html/fog/service/auto-approve-hosts.php >> /var/log/fog-auto-approve.log 2>&1" | sudo tee /etc/cron.d/fog-auto-approve
```

## Usage

### Auto-Approve (runs automatically via cron)

Check log:
```bash
tail -f /var/log/fog-auto-approve.log
```

Run manually:
```bash
# Dry run (see what would happen)
sudo -u www-data php /var/www/html/fog/service/auto-approve-hosts.php --dry-run

# Actually approve
sudo -u www-data php /var/www/html/fog/service/auto-approve-hosts.php

# With specific image
sudo -u www-data php /var/www/html/fog/service/auto-approve-hosts.php --image=Windows11
```

### CSV Import

Create a CSV file (hosts.csv):
```csv
hostname,mac_address,serial_number,image_name,group_name
PC001,aa:bb:cc:dd:ee:ff,ABC123,Windows11,Lab-PCs
PC002,,DEF456,Windows11,Lab-PCs
PC003,,GHI789,,
```

Import:
```bash
# Dry run
sudo -u www-data php /var/www/html/fog/service/csv-import-hosts.php hosts.csv --dry-run

# Actually import
sudo -u www-data php /var/www/html/fog/service/csv-import-hosts.php hosts.csv
```

### Web API (auto-approve)

You can trigger auto-approve via HTTP:
```bash
curl "http://192.168.1.211/fog/service/auto-approve-hosts.php?key=YOUR_API_KEY"

# With image assignment
curl "http://192.168.1.211/fog/service/auto-approve-hosts.php?key=YOUR_API_KEY&image=Windows11"
```

## Workflow Integration

### Before (Manual)
1. PC boots to FOG
2. Registers as pending host
3. Admin opens FOG web UI
4. Finds pending host
5. Approves and configures
6. Assigns image
7. Starts imaging task
8. **Lots of clicking!** ❌

### After (Automated)
1. PC boots to FOG
2. Registers as pending host
3. Cron job approves within 5 minutes
4. Host renamed to serial number
5. Default image assigned
6. Ready for imaging ✓
7. **Hands-free!** ✓

## Integration with Label Printing

Your existing `fog.postdownload` script already prints labels automatically. With auto-registration:

1. PC boots → Auto-registered
2. Imaging starts (via FOG menu or scheduled)
3. Image deploys
4. Post-download script runs
5. Label prints with serial, specs, etc.

## Pre-Staging with Serial Numbers

If you have a list of new PCs coming in:

1. Get serial numbers from purchase order/vendor
2. Create CSV with serial numbers
3. Import to FOG:
```bash
php csv-import-hosts.php new-pcs.csv
```

4. When PCs arrive and boot:
   - FOG sees MAC, matches to pre-staged host
   - Already has image assigned
   - Ready to deploy immediately

## Troubleshooting

### Hosts not being approved
- Check cron is running: `systemctl status cron`
- Check log: `tail -f /var/log/fog-auto-approve.log`
- Run manually to see errors

### CSV import fails
- Check CSV format (no BOM, Unix line endings)
- Ensure column order is correct
- Run with `--dry-run` first

### Wrong image assigned
- Edit `auto-approve-hosts.php` and change `default_image`
- Or use CLI argument: `--image=ImageName`

## Security Notes

- The API key in `auto-approve-hosts.php` should be changed
- Consider restricting web access to internal network only
- CSV import only works via CLI (not web accessible)

