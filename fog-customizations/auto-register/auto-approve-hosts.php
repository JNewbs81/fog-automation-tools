<?php
/**
 * FOG Auto-Approve Pending Hosts
 * 
 * This script automatically approves pending hosts and assigns them
 * to images and groups based on their hardware model.
 * 
 * Can be run via cron or called from the web interface.
 * 
 * Usage:
 *   CLI: php auto-approve-hosts.php [--dry-run]
 *   Web: auto-approve-hosts.php?key=YOUR_API_KEY
 */

// Load FOG core
require_once('/var/www/html/fog/lib/fog/core.class.php');

// =============================================================================
// CONFIGURATION - Edit these settings for your environment
// =============================================================================

$config = [
    'api_key' => 'CHANGE_THIS_TO_A_SECURE_KEY',  // Required for web access
    'auto_rename' => true,      // Rename hosts from MAC to serial number
    'log_file' => '/var/log/fog-auto-approve.log',
    'default_image' => '',      // Fallback image if no model match (empty = don't assign)
    'default_group' => '',      // Fallback group if no model match (empty = don't add)
];

// =============================================================================
// MODEL-BASED IMAGE MAPPING
// =============================================================================
// Map PC models to specific images and groups
// The script checks if the model CONTAINS any of these strings (case-insensitive)
// 
// Format: 'model_pattern' => ['image' => 'ImageName', 'group' => 'GroupName']
// 
// Examples:
//   'OptiPlex 3050' => ['image' => 'Win11-PC', 'group' => 'Desktops']
//   'EliteDesk'     => ['image' => 'Win11-PC', 'group' => 'HP-PCs']
//   'Latitude'      => ['image' => 'Win11-Laptop', 'group' => 'Laptops']

$modelMapping = [
    // ===================
    // DELL DESKTOPS
    // ===================
    'OptiPlex 3050'     => ['image' => 'Dell_3050_Win11 - 11', 'group' => ''],
    'OptiPlex 3060'     => ['image' => 'Dell_3060 - 9', 'group' => ''],
    'OptiPlex 3070'     => ['image' => 'Dell_3070 - 5', 'group' => ''],
    'OptiPlex 3090'     => ['image' => 'Dell_3090 - 6', 'group' => ''],
    'OptiPlex 5080'     => ['image' => 'Dell_5080 - 8', 'group' => ''],
    'OptiPlex 3000'     => ['image' => 'Dell_3000 - 3', 'group' => ''],
    
    // Fallback for other OptiPlex models - uses 3050 image
    'OptiPlex'          => ['image' => 'Dell_3050_Win11 - 11', 'group' => ''],
    
    // ===================
    // DELL WORKSTATIONS
    // ===================
    'Precision 5820'    => ['image' => '5820 - 1', 'group' => ''],
    'Precision Tower'   => ['image' => '5820 - 1', 'group' => ''],
    'Precision'         => ['image' => '5820 - 1', 'group' => ''],
    
    // ===================
    // HP DESKTOPS
    // ===================
    // HP EliteDesk 705 G4 (the mini/micro form factor)
    'EliteDesk 705 G4'  => ['image' => 'HP_Micro_W11 - 10', 'group' => ''],
    'EliteDesk 705'     => ['image' => 'HP_Micro_W11 - 10', 'group' => ''],
    
    // HP M01 series
    'HP M01'            => ['image' => 'HP_M01xxxx - 7', 'group' => ''],
    'M01'               => ['image' => 'HP_M01xxxx - 7', 'group' => ''],
    
    // HP White/other models
    'ProDesk'           => ['image' => 'HP_White - 4', 'group' => ''],
    'EliteDesk'         => ['image' => 'HP_Micro_W11 - 10', 'group' => ''],
    
    // ===================
    // LENOVO (add when you have images)
    // ===================
    // 'ThinkCentre'    => ['image' => 'YOUR_LENOVO_IMAGE', 'group' => ''],
    // 'ThinkPad'       => ['image' => 'YOUR_LENOVO_IMAGE', 'group' => ''],
];

// =============================================================================
// END CONFIGURATION
// =============================================================================

// Parse arguments
$isDryRun = false;

if (php_sapi_name() === 'cli') {
    foreach ($argv as $arg) {
        if ($arg === '--dry-run') {
            $isDryRun = true;
        }
    }
} else {
    header('Content-Type: application/json');
    
    $providedKey = $_GET['key'] ?? $_POST['key'] ?? '';
    if ($providedKey !== $config['api_key'] || $config['api_key'] === 'CHANGE_THIS_TO_A_SECURE_KEY') {
        http_response_code(403);
        echo json_encode(['error' => 'Invalid or unconfigured API key']);
        exit(1);
    }
    
    $isDryRun = isset($_GET['dry-run']) || isset($_POST['dry-run']);
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

// Function to find matching model config
function getModelConfig($model) {
    global $modelMapping, $config;
    
    if (empty($model)) {
        return [
            'image' => $config['default_image'],
            'group' => $config['default_group'],
            'matched' => false,
            'pattern' => null
        ];
    }
    
    // Check each pattern (more specific patterns should be listed first)
    foreach ($modelMapping as $pattern => $mapping) {
        if (stripos($model, $pattern) !== false) {
            return [
                'image' => $mapping['image'] ?? $config['default_image'],
                'group' => $mapping['group'] ?? $config['default_group'],
                'matched' => true,
                'pattern' => $pattern
            ];
        }
    }
    
    // No match found, use defaults
    return [
        'image' => $config['default_image'],
        'group' => $config['default_group'],
        'matched' => false,
        'pattern' => null
    ];
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
logMsg("Model mappings configured: " . count($modelMapping));

// Cache for images and groups
$imageCache = [];
$groupCache = [];

function getImage($name) {
    global $imageCache;
    if (empty($name)) return null;
    
    if (!isset($imageCache[$name])) {
        $images = FOGCore::getClass('ImageManager')->find(['name' => $name]);
        $imageCache[$name] = ($images && count($images) > 0) ? $images[0] : null;
    }
    return $imageCache[$name];
}

function getGroup($name) {
    global $groupCache;
    if (empty($name)) return null;
    
    if (!isset($groupCache[$name])) {
        $groups = FOGCore::getClass('GroupManager')->find(['name' => $name]);
        $groupCache[$name] = ($groups && count($groups) > 0) ? $groups[0] : null;
    }
    return $groupCache[$name];
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
    
    // Get inventory for serial number and model
    $inventory = $host->get('inventory');
    $serial = $inventory ? $inventory->get('sysserial') : '';
    $model = $inventory ? $inventory->get('sysproduct') : '';
    $manufacturer = $inventory ? $inventory->get('sysman') : '';
    
    logMsg("Processing: $hostName");
    logMsg("  MAC: $hostMac");
    logMsg("  Model: $manufacturer $model");
    logMsg("  Serial: $serial");
    
    // Get image/group based on model
    $modelConfig = getModelConfig($model);
    
    if ($modelConfig['matched']) {
        logMsg("  Model matched pattern: '{$modelConfig['pattern']}'");
    } else {
        logMsg("  No model match, using defaults");
    }
    
    $result = [
        'id' => $hostId,
        'original_name' => $hostName,
        'mac' => $hostMac,
        'serial' => $serial,
        'model' => "$manufacturer $model",
        'matched_pattern' => $modelConfig['pattern'],
        'assigned_image' => $modelConfig['image'],
        'assigned_group' => $modelConfig['group'],
        'actions' => [],
    ];
    
    // Get image object
    $image = getImage($modelConfig['image']);
    if ($modelConfig['image'] && !$image) {
        logMsg("  WARNING: Image '{$modelConfig['image']}' not found in FOG");
    }
    
    // Get group object
    $group = getGroup($modelConfig['group']);
    if ($modelConfig['group'] && !$group) {
        logMsg("  WARNING: Group '{$modelConfig['group']}' not found in FOG");
    }
    
    if (!$isDryRun) {
        // Approve the host
        $host->set('pending', 0);
        
        // Rename to serial number if configured and serial exists
        if ($config['auto_rename'] && !empty($serial) && $serial !== 'N/A' && $serial !== 'To Be Filled By O.E.M.') {
            $newName = preg_replace('/[^a-zA-Z0-9\-]/', '', $serial);
            if (!empty($newName) && strlen($newName) >= 4) {
                $host->set('name', $newName);
                $result['new_name'] = $newName;
                $result['actions'][] = "Renamed to $newName";
                logMsg("  -> Renamed to: $newName");
            }
        }
        
        // Assign image
        if ($image) {
            $host->set('imageID', $image->get('id'));
            $result['actions'][] = "Assigned image: {$modelConfig['image']}";
            logMsg("  -> Assigned image: {$modelConfig['image']}");
        }
        
        // Save changes
        if ($host->save()) {
            $result['status'] = 'approved';
            $result['actions'][] = 'Approved';
            $approved++;
            logMsg("  -> Approved");
            
            // Add to group (after save)
            if ($group) {
                $group->addHost($hostId);
                $group->save();
                $result['actions'][] = "Added to group: {$modelConfig['group']}";
                logMsg("  -> Added to group: {$modelConfig['group']}");
            }
        } else {
            $result['status'] = 'error';
            $result['error'] = 'Failed to save';
            logMsg("  -> ERROR: Failed to save host");
        }
    } else {
        $result['status'] = 'would_approve';
        $result['actions'][] = 'Would approve (dry run)';
        if ($config['auto_rename'] && !empty($serial)) {
            $newName = preg_replace('/[^a-zA-Z0-9\-]/', '', $serial);
            if (!empty($newName) && strlen($newName) >= 4) {
                $result['actions'][] = "Would rename to: $newName";
            }
        }
        if ($image) {
            $result['actions'][] = "Would assign image: {$modelConfig['image']}";
        }
        if ($group) {
            $result['actions'][] = "Would add to group: {$modelConfig['group']}";
        }
        $approved++;
    }
    
    $results[] = $result;
    logMsg("");
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
