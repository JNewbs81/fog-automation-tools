// Global state
let currentManufacturer = 'dell';
let currentConfig = null;
let currentFileName = '';

// Switch between manufacturer tabs
function switchTab(manufacturer) {
    currentManufacturer = manufacturer;
    
    // Update tab buttons
    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
    });
    event.target.classList.add('active');
    
    // Update tab content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    document.getElementById(`${manufacturer}-tab`).classList.add('active');
}

// Setup drag and drop for all upload areas
document.addEventListener('DOMContentLoaded', function() {
    ['dell', 'hp', 'lenovo'].forEach(mfr => {
        const uploadArea = document.getElementById(`${mfr}-upload`);
        
        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('dragover');
        });
        
        uploadArea.addEventListener('dragleave', () => {
            uploadArea.classList.remove('dragover');
        });
        
        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('dragover');
            const file = e.dataTransfer.files[0];
            if (file) {
                handleFileUpload(mfr, file);
            }
        });
    });
});

// Handle file upload
function handleFileUpload(manufacturer, file) {
    if (!file) return;
    
    currentFileName = file.name;
    const reader = new FileReader();
    
    reader.onload = function(e) {
        const content = e.target.result;
        currentConfig = parseConfig(manufacturer, content);
        
        // Show file info
        const fileInfo = document.getElementById(`${manufacturer}-file-info`);
        fileInfo.style.display = 'block';
        fileInfo.innerHTML = `
            <strong>📄 ${file.name}</strong><br>
            Size: ${(file.size / 1024).toFixed(2)} KB<br>
            Settings detected: ${Object.keys(currentConfig).length}
        `;
        
        // Update preview
        updatePreview();
        
        // Enable download button
        document.getElementById('download-btn').disabled = false;
        document.getElementById('upload-server-btn').disabled = false;
        
        showSuccess(`Configuration loaded successfully! Found ${Object.keys(currentConfig).length} settings.`);
    };
    
    reader.readAsText(file);
}

// Parse configuration based on manufacturer
function parseConfig(manufacturer, content) {
    const config = {};
    
    if (manufacturer === 'dell') {
        // Parse Dell CCTK format
        const lines = content.split('\n');
        lines.forEach(line => {
            line = line.trim();
            if (line.startsWith('--') || line.includes('=')) {
                const match = line.match(/--?(\w+)=(.+)/);
                if (match) {
                    config[match[1]] = match[2];
                }
            }
        });
    } else if (manufacturer === 'hp') {
        // Parse HP BCU format
        const lines = content.split('\n');
        let currentSetting = '';
        lines.forEach(line => {
            line = line.trim();
            if (line && !line.startsWith(';') && !line.startsWith('BIOSConfig')) {
                if (line.startsWith('*')) {
                    if (currentSetting) {
                        config[currentSetting] = line.substring(1).trim();
                    }
                } else if (!line.includes('\t')) {
                    currentSetting = line;
                }
            }
        });
    } else if (manufacturer === 'lenovo') {
        // Parse Lenovo INI format
        const lines = content.split('\n');
        lines.forEach(line => {
            line = line.trim();
            if (line && !line.startsWith(';')) {
                const parts = line.split(',');
                if (parts.length === 2) {
                    config[parts[0].trim()] = parts[1].trim();
                }
            }
        });
    }
    
    return config;
}

// Apply FOG imaging settings
function applySettings() {
    if (!currentConfig) {
        showError('Please upload a configuration file first!');
        return;
    }
    
    const secureBoot = document.getElementById('setting-secureboot').value;
    const bootMode = document.getElementById('setting-bootmode').value;
    const legacy = document.getElementById('setting-legacy').value;
    const pxe = document.getElementById('setting-pxe').value;
    const uefiNetwork = document.getElementById('setting-uefinetwork').value;
    const sata = document.getElementById('setting-sata').value;
    const warnings = document.getElementById('setting-warnings').checked;
    const wol = document.getElementById('setting-wol').value;
    
    // Apply settings based on manufacturer
    if (currentManufacturer === 'dell') {
        currentConfig['SecureBoot'] = secureBoot;
        currentConfig['BootMode'] = bootMode === 'UEFI' ? 'Uefi' : 'Bios';
        currentConfig['LegacyOrom'] = legacy;
        currentConfig['EmbNic1'] = 'Enabled';
        currentConfig['EmbNic1Ipv4'] = pxe;
        currentConfig['UefiNwStack'] = uefiNetwork;
        currentConfig['EmbSataRaid'] = sata;
        currentConfig['WarningsAndErr'] = warnings ? 'ContWrnErr' : 'PromptWrnErr';
        currentConfig['WakeOnLan'] = wol;
    } else if (currentManufacturer === 'hp') {
        currentConfig['SecureBoot'] = secureBoot;
        currentConfig['Boot Mode'] = bootMode === 'UEFI' ? 'UEFI Native (Without CSM)' : 'Legacy';
        currentConfig['Legacy Boot Options'] = legacy === 'Disabled' ? 'Disable' : 'Enable';
        currentConfig['CSM Support'] = legacy === 'Disabled' ? 'Disable' : 'Enable';
        currentConfig['Network (PXE) Boot'] = pxe === 'Enabled' ? 'Enable' : 'Disable';
        currentConfig['IPv4 PXE Boot'] = pxe === 'Enabled' ? 'Enable' : 'Disable';
        currentConfig['Wake on LAN'] = wol === 'Enabled' ? 'Boot to Hard Drive' : 'Disabled';
    } else if (currentManufacturer === 'lenovo') {
        currentConfig['SecureBoot'] = secureBoot === 'Disabled' ? 'Disable' : 'Enable';
        currentConfig['BootMode'] = bootMode === 'UEFI' ? 'UEFI Only' : 'Legacy Only';
        currentConfig['CSM Support'] = legacy === 'Disabled' ? 'Disable' : 'Enable';
        currentConfig['NetworkBoot'] = pxe === 'Enabled' ? 'Enable' : 'Disable';
        currentConfig['PXEIPv4NetworkStack'] = pxe === 'Enabled' ? 'Enable' : 'Disable';
        currentConfig['WakeOnLAN'] = wol === 'Enabled' ? 'Enable' : 'Disable';
    }
    
    updatePreview();
    showSuccess('Settings applied! You can now download or upload the configuration.');
}

// Update preview
function updatePreview() {
    const preview = document.getElementById('config-preview');
    let output = '';
    
    if (currentManufacturer === 'dell') {
        output = '; Dell CCTK Configuration for FOG Imaging\n';
        output += '; Generated by FOG BIOS Configuration Manager\n\n';
        for (const [key, value] of Object.entries(currentConfig)) {
            output += `--${key}=${value}\n`;
        }
    } else if (currentManufacturer === 'hp') {
        output = 'BIOSConfig 1.0\n';
        output += ';\n';
        output += '; HP BIOS Configuration for FOG Imaging\n';
        output += '; Generated by FOG BIOS Configuration Manager\n';
        output += ';\n\n';
        for (const [key, value] of Object.entries(currentConfig)) {
            output += `${key}\n\t*${value}\n\n`;
        }
    } else if (currentManufacturer === 'lenovo') {
        output = ';\n';
        output += '; Lenovo Think BIOS Configuration for FOG Imaging\n';
        output += '; Generated by FOG BIOS Configuration Manager\n';
        output += ';\n\n';
        for (const [key, value] of Object.entries(currentConfig)) {
            output += `${key},${value}\n`;
        }
    }
    
    preview.textContent = output;
}

// Download configuration
function downloadConfig() {
    if (!currentConfig) {
        showError('No configuration to download!');
        return;
    }
    
    const preview = document.getElementById('config-preview').textContent;
    const blob = new Blob([preview], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    
    let filename = 'fog-config';
    if (currentManufacturer === 'dell') filename += '.cctk';
    else if (currentManufacturer === 'hp') filename += '.REPSET';
    else if (currentManufacturer === 'lenovo') filename += '.ini';
    
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    showSuccess(`Configuration downloaded as ${filename}`);
}

// Upload to FOG server
async function uploadToServer() {
    if (!currentConfig) {
        showError('No configuration to upload!');
        return;
    }
    
    const preview = document.getElementById('config-preview').textContent;
    const serverUrl = prompt('Enter FOG server address (e.g., 192.168.1.211):', '192.168.1.211');
    
    if (!serverUrl) return;
    
    let filename = 'fog-config';
    let path = '';
    
    if (currentManufacturer === 'dell') {
        filename = 'fog-bios-config.cctk';
        path = '/dell/';
    } else if (currentManufacturer === 'hp') {
        filename = 'fog-config.REPSET';
        path = '/hp/';
    } else if (currentManufacturer === 'lenovo') {
        filename = 'fog-config.ini';
        path = '/lenovo/';
    }
    
    try {
        const response = await fetch(`http://${serverUrl}/fog-automation-tools/upload.php`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                manufacturer: currentManufacturer,
                filename: filename,
                content: preview,
                path: path
            })
        });
        
        if (response.ok) {
            showSuccess(`Configuration uploaded to FOG server successfully!`);
        } else {
            throw new Error('Upload failed');
        }
    } catch (error) {
        showError('Could not upload to server. You can download the file and upload manually via SCP.');
        console.error(error);
    }
}

// Show success message
function showSuccess(message) {
    const successMsg = document.getElementById('success-msg');
    const errorMsg = document.getElementById('error-msg');
    errorMsg.style.display = 'none';
    successMsg.textContent = message;
    successMsg.style.display = 'block';
    setTimeout(() => {
        successMsg.style.display = 'none';
    }, 5000);
}

// Show error message
function showError(message) {
    const successMsg = document.getElementById('success-msg');
    const errorMsg = document.getElementById('error-msg');
    successMsg.style.display = 'none';
    errorMsg.textContent = message;
    errorMsg.style.display = 'block';
    setTimeout(() => {
        errorMsg.style.display = 'none';
    }, 5000);
}
