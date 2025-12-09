<?php
/**
 * FOG CSV Host Import
 * 
 * Pre-stage hosts in FOG by importing from a CSV file.
 * Useful for importing known serial numbers before imaging.
 * 
 * CSV Format:
 *   hostname,mac_address,serial_number,image_name,group_name
 * 
 * Only hostname is required. Other fields are optional.
 * MAC can be left empty and will be populated during registration.
 * 
 * Usage:
 *   php csv-import-hosts.php hosts.csv [--dry-run]
 */

// Load FOG core
require_once('/var/www/html/fog/lib/fog/core.class.php');

if (php_sapi_name() !== 'cli') {
    die("This script must be run from command line\n");
}

// Parse arguments
$csvFile = '';
$isDryRun = false;

foreach ($argv as $i => $arg) {
    if ($i === 0) continue;
    
    if ($arg === '--dry-run') {
        $isDryRun = true;
    } elseif (empty($csvFile) && file_exists($arg)) {
        $csvFile = $arg;
    }
}

if (empty($csvFile)) {
    echo "Usage: php csv-import-hosts.php <csvfile> [--dry-run]\n";
    echo "\nCSV Format:\n";
    echo "  hostname,mac_address,serial_number,image_name,group_name\n";
    echo "\nExample:\n";
    echo "  PC001,aa:bb:cc:dd:ee:ff,ABC123,Windows11,Lab-PCs\n";
    echo "  PC002,,DEF456,Windows11,Lab-PCs\n";
    exit(1);
}

// Initialize FOG
try {
    FOGCore::getClass('FOGCore');
} catch (Exception $e) {
    die("Failed to initialize FOG: " . $e->getMessage() . "\n");
}

echo "FOG CSV Host Import\n";
echo "===================\n\n";

if ($isDryRun) {
    echo "** DRY RUN MODE - No changes will be made **\n\n";
}

// Read CSV
$handle = fopen($csvFile, 'r');
if (!$handle) {
    die("Cannot open file: $csvFile\n");
}

// Skip header if present
$firstLine = fgetcsv($handle);
$hasHeader = false;

// Check if first line looks like a header
if ($firstLine && (strtolower($firstLine[0]) === 'hostname' || strtolower($firstLine[0]) === 'name')) {
    $hasHeader = true;
    echo "Detected header row, skipping...\n";
} else {
    // Not a header, rewind
    rewind($handle);
}

$imported = 0;
$skipped = 0;
$errors = 0;
$lineNum = $hasHeader ? 1 : 0;

while (($data = fgetcsv($handle)) !== false) {
    $lineNum++;
    
    // Parse CSV columns
    $hostname = trim($data[0] ?? '');
    $mac = trim($data[1] ?? '');
    $serial = trim($data[2] ?? '');
    $imageName = trim($data[3] ?? '');
    $groupName = trim($data[4] ?? '');
    
    if (empty($hostname)) {
        echo "Line $lineNum: Skipping empty hostname\n";
        $skipped++;
        continue;
    }
    
    echo "Line $lineNum: Processing '$hostname'";
    if (!empty($mac)) echo " (MAC: $mac)";
    if (!empty($serial)) echo " [Serial: $serial]";
    echo "\n";
    
    // Check if host already exists
    $existingHost = null;
    
    // Try to find by MAC first
    if (!empty($mac)) {
        $mac = strtolower(str_replace(['-', ':'], '', $mac));
        $mac = implode(':', str_split($mac, 2));
        
        $existingHost = FOGCore::getClass('HostManager')->getHostByMacAddresses($mac);
    }
    
    // Try to find by name
    if (!$existingHost) {
        $hosts = FOGCore::getClass('HostManager')->find(['name' => $hostname]);
        if ($hosts && count($hosts) > 0) {
            $existingHost = $hosts[0];
        }
    }
    
    if ($existingHost) {
        echo "  -> Host already exists (ID: {$existingHost->get('id')}), skipping\n";
        $skipped++;
        continue;
    }
    
    // Get image ID if specified
    $imageID = 0;
    if (!empty($imageName)) {
        $images = FOGCore::getClass('ImageManager')->find(['name' => $imageName]);
        if ($images && count($images) > 0) {
            $imageID = $images[0]->get('id');
            echo "  -> Image: $imageName (ID: $imageID)\n";
        } else {
            echo "  -> WARNING: Image '$imageName' not found\n";
        }
    }
    
    // Get group if specified
    $group = null;
    if (!empty($groupName)) {
        $groups = FOGCore::getClass('GroupManager')->find(['name' => $groupName]);
        if ($groups && count($groups) > 0) {
            $group = $groups[0];
            echo "  -> Group: $groupName (ID: {$group->get('id')})\n";
        } else {
            echo "  -> WARNING: Group '$groupName' not found\n";
        }
    }
    
    if ($isDryRun) {
        echo "  -> Would create host '$hostname'\n";
        $imported++;
        continue;
    }
    
    // Create new host
    try {
        $host = FOGCore::getClass('Host')
            ->set('name', $hostname)
            ->set('pending', 0)
            ->set('imageID', $imageID);
        
        // Set MAC if provided
        if (!empty($mac)) {
            // Primary MAC is set separately
            $host->addPriMAC($mac);
        }
        
        if ($host->save()) {
            $hostId = $host->get('id');
            echo "  -> Created host (ID: $hostId)\n";
            
            // Set inventory serial if provided
            if (!empty($serial)) {
                $inventory = $host->get('inventory');
                if (!$inventory) {
                    $inventory = FOGCore::getClass('Inventory')
                        ->set('hostID', $hostId);
                }
                $inventory->set('sysserial', $serial);
                $inventory->save();
                echo "  -> Set serial: $serial\n";
            }
            
            // Add to group
            if ($group) {
                $group->addHost($hostId);
                $group->save();
                echo "  -> Added to group: $groupName\n";
            }
            
            $imported++;
        } else {
            echo "  -> ERROR: Failed to create host\n";
            $errors++;
        }
    } catch (Exception $e) {
        echo "  -> ERROR: " . $e->getMessage() . "\n";
        $errors++;
    }
}

fclose($handle);

echo "\n";
echo "===================\n";
echo "Import Complete\n";
echo "===================\n";
echo "Imported: $imported\n";
echo "Skipped:  $skipped\n";
echo "Errors:   $errors\n";

if ($isDryRun) {
    echo "\n** This was a dry run. Run without --dry-run to make changes. **\n";
}

