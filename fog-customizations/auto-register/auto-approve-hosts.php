<?php
/**
 * FOG Auto-Approve Pending Hosts
 * 
 * This script automatically approves pending hosts and optionally assigns them
 * to a default image and group based on configuration.
 * 
 * Can be run via cron or called from the web interface.
 * 
 * Usage:
 *   CLI: php auto-approve-hosts.php [--dry-run] [--image=ImageName] [--group=GroupName]
 *   Web: auto-approve-hosts.php?key=YOUR_API_KEY&image=ImageName
 */

// Load FOG core
require_once('/var/www/html/fog/lib/fog/core.class.php');

// Configuration
$config = [
    'api_key' => 'CHANGE_THIS_TO_A_SECURE_KEY',  // Required for web access
    'default_image' => '',      // Default image name to assign (empty = don't assign)
    'default_group' => '',      // Default group name to add to (empty = don't add)
    'auto_rename' => true,      // Rename hosts from MAC to serial number
    'log_file' => '/var/log/fog-auto-approve.log',
];

// Parse arguments
$isDryRun = false;
$imageName = $config['default_image'];
$groupName = $config['default_group'];

if (php_sapi_name() === 'cli') {
    // CLI mode
    foreach ($argv as $arg) {
        if ($arg === '--dry-run') {
            $isDryRun = true;
        } elseif (strpos($arg, '--image=') === 0) {
            $imageName = substr($arg, 8);
        } elseif (strpos($arg, '--group=') === 0) {
            $groupName = substr($arg, 8);
        }
    }
} else {
    // Web mode - require API key
    header('Content-Type: application/json');
    
    $providedKey = $_GET['key'] ?? $_POST['key'] ?? '';
    if ($providedKey !== $config['api_key'] || $config['api_key'] === 'CHANGE_THIS_TO_A_SECURE_KEY') {
        http_response_code(403);
        echo json_encode(['error' => 'Invalid or unconfigured API key']);
        exit(1);
    }
    
    $isDryRun = isset($_GET['dry-run']) || isset($_POST['dry-run']);
    $imageName = $_GET['image'] ?? $_POST['image'] ?? $config['default_image'];
    $groupName = $_GET['group'] ?? $_POST['group'] ?? $config['default_group'];
}

// Logging function
function logMsg($msg) {
    global $config;
    $timestamp = date('Y-m-d H:i:s');
    $line = "[$timestamp] $msg\n";
    file_put_contents($config['log_file'], $line, FILE_APPEND);
    if (php_sapi_name() === 'cli') {
        echo $line;
    }
}

// Initialize FOG
try {
    FOGCore::getClass('FOGCore');
} catch (Exception $e) {
    $error = "Failed to initialize FOG: " . $e->getMessage();
    logMsg("ERROR: $error");
    if (php_sapi_name() !== 'cli') {
        echo json_encode(['error' => $error]);
    }
    exit(1);
}

logMsg("Starting auto-approve process" . ($isDryRun ? " (DRY RUN)" : ""));

// Get default image if specified
$defaultImage = null;
if (!empty($imageName)) {
    $defaultImage = FOGCore::getClass('ImageManager')->find(['name' => $imageName]);
    if ($defaultImage && count($defaultImage) > 0) {
        $defaultImage = $defaultImage[0];
        logMsg("Default image: {$imageName} (ID: {$defaultImage->get('id')})");
    } else {
        logMsg("WARNING: Image '$imageName' not found");
        $defaultImage = null;
    }
}

// Get default group if specified
$defaultGroup = null;
if (!empty($groupName)) {
    $defaultGroup = FOGCore::getClass('GroupManager')->find(['name' => $groupName]);
    if ($defaultGroup && count($defaultGroup) > 0) {
        $defaultGroup = $defaultGroup[0];
        logMsg("Default group: {$groupName} (ID: {$defaultGroup->get('id')})");
    } else {
        logMsg("WARNING: Group '$groupName' not found");
        $defaultGroup = null;
    }
}

// Get pending hosts
$pendingHosts = FOGCore::getClass('HostManager')->find(['pending' => 1]);
$count = count($pendingHosts);
logMsg("Found $count pending host(s)");

$approved = 0;
$results = [];

foreach ($pendingHosts as $host) {
    $hostId = $host->get('id');
    $hostName = $host->get('name');
    $hostMac = $host->get('mac')->__toString();
    
    // Get inventory for serial number
    $inventory = $host->get('inventory');
    $serial = $inventory ? $inventory->get('sysserial') : '';
    $model = $inventory ? $inventory->get('sysproduct') : '';
    
    logMsg("Processing: $hostName (MAC: $hostMac, Serial: $serial, Model: $model)");
    
    $result = [
        'id' => $hostId,
        'original_name' => $hostName,
        'mac' => $hostMac,
        'serial' => $serial,
        'model' => $model,
        'actions' => [],
    ];
    
    if (!$isDryRun) {
        // Approve the host
        $host->set('pending', 0);
        
        // Rename to serial number if configured and serial exists
        if ($config['auto_rename'] && !empty($serial) && $serial !== 'N/A') {
            // Clean serial for use as hostname
            $newName = preg_replace('/[^a-zA-Z0-9\-]/', '', $serial);
            if (!empty($newName)) {
                $host->set('name', $newName);
                $result['new_name'] = $newName;
                $result['actions'][] = "Renamed to $newName";
            }
        }
        
        // Assign default image
        if ($defaultImage) {
            $host->set('imageID', $defaultImage->get('id'));
            $result['actions'][] = "Assigned image: $imageName";
        }
        
        // Save changes
        if ($host->save()) {
            $result['status'] = 'approved';
            $result['actions'][] = 'Approved';
            $approved++;
            
            // Add to group (after save)
            if ($defaultGroup) {
                $defaultGroup->addHost($hostId);
                $defaultGroup->save();
                $result['actions'][] = "Added to group: $groupName";
            }
            
            logMsg("  -> Approved" . (isset($result['new_name']) ? ", renamed to {$result['new_name']}" : ""));
        } else {
            $result['status'] = 'error';
            $result['error'] = 'Failed to save';
            logMsg("  -> ERROR: Failed to save host");
        }
    } else {
        $result['status'] = 'would_approve';
        $result['actions'][] = 'Would approve (dry run)';
        if ($config['auto_rename'] && !empty($serial)) {
            $result['actions'][] = "Would rename to: " . preg_replace('/[^a-zA-Z0-9\-]/', '', $serial);
        }
        $approved++;
    }
    
    $results[] = $result;
}

$summary = [
    'total_pending' => $count,
    'processed' => $approved,
    'dry_run' => $isDryRun,
    'hosts' => $results,
];

logMsg("Completed: $approved of $count hosts " . ($isDryRun ? "would be " : "") . "approved");

if (php_sapi_name() !== 'cli') {
    echo json_encode($summary, JSON_PRETTY_PRINT);
}

