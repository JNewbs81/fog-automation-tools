<?php
/**
 * FOG BIOS Configuration Upload Handler
 * Receives configuration files from the web interface and saves them
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

// Get JSON data
$json = file_get_contents('php://input');
$data = json_decode($json, true);

if (!$data || !isset($data['manufacturer']) || !isset($data['filename']) || !isset($data['content'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing required fields']);
    exit();
}

$manufacturer = $data['manufacturer'];
$filename = basename($data['filename']); // Security: prevent directory traversal
$content = $data['content'];
$path = isset($data['path']) ? $data['path'] : '/';

// Base directory for BIOS tools
$baseDir = '/var/www/html/fog-automation-tools/bios-tools';

// Determine target directory
$targetDir = $baseDir . $path;

// Create directory if it doesn't exist
if (!file_exists($targetDir)) {
    if (!mkdir($targetDir, 0755, true)) {
        http_response_code(500);
        echo json_encode(['error' => 'Could not create directory']);
        exit();
    }
}

// Full file path
$filePath = $targetDir . $filename;

// Write file
if (file_put_contents($filePath, $content) === false) {
    http_response_code(500);
    echo json_encode(['error' => 'Could not write file']);
    exit();
}

// Set permissions
chmod($filePath, 0644);

// Log the upload
$logFile = $baseDir . '/upload.log';
$logEntry = date('Y-m-d H:i:s') . " - Uploaded: $manufacturer/$filename (" . strlen($content) . " bytes)\n";
file_put_contents($logFile, $logEntry, FILE_APPEND);

// Success response
http_response_code(200);
echo json_encode([
    'success' => true,
    'message' => 'Configuration uploaded successfully',
    'file' => $filePath,
    'size' => strlen($content)
]);
?>
