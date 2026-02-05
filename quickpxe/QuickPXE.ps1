# QuickPXE.ps1
# A Rufus-style tool for creating WinPE USB drives with BIOS configuration tools
# Requires: Windows 10/11, Administrator privileges

#Requires -RunAsAdministrator

# Get script directory
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import library functions
. "$script:ScriptDir\lib\USB-Functions.ps1"
. "$script:ScriptDir\lib\ADK-Functions.ps1"
. "$script:ScriptDir\lib\WinPE-Functions.ps1"
. "$script:ScriptDir\lib\BIOS-Functions.ps1"

# Paths
$script:ConfigsPath = Join-Path $script:ScriptDir "configs"
$script:ToolsPath = Join-Path $script:ScriptDir "tools"
$script:StartnetPath = Join-Path $script:ScriptDir "startnet-quickpxe.cmd"

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

#region Main Form
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "QuickPXE - BIOS Configuration USB Tool"
$mainForm.Size = New-Object System.Drawing.Size(550, 650)
$mainForm.StartPosition = "CenterScreen"
$mainForm.FormBorderStyle = "FixedSingle"
$mainForm.MaximizeBox = $false
$mainForm.Icon = [System.Drawing.SystemIcons]::Application

# Tab Control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(515, 480)

#region USB Tab
$tabUSB = New-Object System.Windows.Forms.TabPage
$tabUSB.Text = "USB Drive"
$tabUSB.Padding = New-Object System.Windows.Forms.Padding(10)

# Device Group
$grpDevice = New-Object System.Windows.Forms.GroupBox
$grpDevice.Text = "Device"
$grpDevice.Location = New-Object System.Drawing.Point(10, 10)
$grpDevice.Size = New-Object System.Drawing.Size(485, 80)

$lblDevice = New-Object System.Windows.Forms.Label
$lblDevice.Text = "USB Drive:"
$lblDevice.Location = New-Object System.Drawing.Point(10, 30)
$lblDevice.AutoSize = $true

$cmbDrive = New-Object System.Windows.Forms.ComboBox
$cmbDrive.Location = New-Object System.Drawing.Point(80, 27)
$cmbDrive.Size = New-Object System.Drawing.Size(300, 25)
$cmbDrive.DropDownStyle = "DropDownList"

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(390, 25)
$btnRefresh.Size = New-Object System.Drawing.Size(80, 27)

$grpDevice.Controls.AddRange(@($lblDevice, $cmbDrive, $btnRefresh))

# ADK Status Group
$grpADK = New-Object System.Windows.Forms.GroupBox
$grpADK.Text = "Windows ADK Status"
$grpADK.Location = New-Object System.Drawing.Point(10, 100)
$grpADK.Size = New-Object System.Drawing.Size(485, 80)

$lblADKStatus = New-Object System.Windows.Forms.Label
$lblADKStatus.Text = "Checking ADK installation..."
$lblADKStatus.Location = New-Object System.Drawing.Point(10, 25)
$lblADKStatus.Size = New-Object System.Drawing.Size(350, 20)

$lblWinPEStatus = New-Object System.Windows.Forms.Label
$lblWinPEStatus.Text = "Checking WinPE add-on..."
$lblWinPEStatus.Location = New-Object System.Drawing.Point(10, 48)
$lblWinPEStatus.Size = New-Object System.Drawing.Size(350, 20)

$btnInstallADK = New-Object System.Windows.Forms.Button
$btnInstallADK.Text = "Install ADK"
$btnInstallADK.Location = New-Object System.Drawing.Point(370, 30)
$btnInstallADK.Size = New-Object System.Drawing.Size(100, 35)
$btnInstallADK.Enabled = $false

$grpADK.Controls.AddRange(@($lblADKStatus, $lblWinPEStatus, $btnInstallADK))

# USB Actions Group
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Text = "USB Actions"
$grpActions.Location = New-Object System.Drawing.Point(10, 190)
$grpActions.Size = New-Object System.Drawing.Size(485, 120)

$btnCreateUSB = New-Object System.Windows.Forms.Button
$btnCreateUSB.Text = "Create WinPE USB"
$btnCreateUSB.Location = New-Object System.Drawing.Point(10, 30)
$btnCreateUSB.Size = New-Object System.Drawing.Size(220, 40)
$btnCreateUSB.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$btnUpdateUSB = New-Object System.Windows.Forms.Button
$btnUpdateUSB.Text = "Update Existing USB"
$btnUpdateUSB.Location = New-Object System.Drawing.Point(250, 30)
$btnUpdateUSB.Size = New-Object System.Drawing.Size(220, 40)
$btnUpdateUSB.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$lblCreateDesc = New-Object System.Windows.Forms.Label
$lblCreateDesc.Text = "Creates a new WinPE USB with BIOS tools"
$lblCreateDesc.Location = New-Object System.Drawing.Point(10, 75)
$lblCreateDesc.Size = New-Object System.Drawing.Size(220, 30)
$lblCreateDesc.ForeColor = [System.Drawing.Color]::Gray

$lblUpdateDesc = New-Object System.Windows.Forms.Label
$lblUpdateDesc.Text = "Updates configs on existing USB"
$lblUpdateDesc.Location = New-Object System.Drawing.Point(250, 75)
$lblUpdateDesc.Size = New-Object System.Drawing.Size(220, 30)
$lblUpdateDesc.ForeColor = [System.Drawing.Color]::Gray

$grpActions.Controls.AddRange(@($btnCreateUSB, $btnUpdateUSB, $lblCreateDesc, $lblUpdateDesc))

# Warning Label
$lblWarning = New-Object System.Windows.Forms.Label
$lblWarning.Text = "WARNING: Creating a new USB will erase all data on the selected drive!"
$lblWarning.Location = New-Object System.Drawing.Point(10, 320)
$lblWarning.Size = New-Object System.Drawing.Size(485, 20)
$lblWarning.ForeColor = [System.Drawing.Color]::Red
$lblWarning.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$tabUSB.Controls.AddRange(@($grpDevice, $grpADK, $grpActions, $lblWarning))
#endregion

#region BIOS Config Tab
$tabBIOS = New-Object System.Windows.Forms.TabPage
$tabBIOS.Text = "BIOS Configuration"
$tabBIOS.Padding = New-Object System.Windows.Forms.Padding(10)

# System Info Group
$grpSysInfo = New-Object System.Windows.Forms.GroupBox
$grpSysInfo.Text = "Current System"
$grpSysInfo.Location = New-Object System.Drawing.Point(10, 10)
$grpSysInfo.Size = New-Object System.Drawing.Size(485, 100)

$lblManufacturer = New-Object System.Windows.Forms.Label
$lblManufacturer.Text = "Manufacturer: Detecting..."
$lblManufacturer.Location = New-Object System.Drawing.Point(10, 25)
$lblManufacturer.Size = New-Object System.Drawing.Size(460, 20)

$lblModel = New-Object System.Windows.Forms.Label
$lblModel.Text = "Model: Detecting..."
$lblModel.Location = New-Object System.Drawing.Point(10, 48)
$lblModel.Size = New-Object System.Drawing.Size(460, 20)

$lblSerial = New-Object System.Windows.Forms.Label
$lblSerial.Text = "Serial: Detecting..."
$lblSerial.Location = New-Object System.Drawing.Point(10, 71)
$lblSerial.Size = New-Object System.Drawing.Size(460, 20)

$grpSysInfo.Controls.AddRange(@($lblManufacturer, $lblModel, $lblSerial))

# Extract/Import Group
$grpExtract = New-Object System.Windows.Forms.GroupBox
$grpExtract.Text = "BIOS Configuration"
$grpExtract.Location = New-Object System.Drawing.Point(10, 120)
$grpExtract.Size = New-Object System.Drawing.Size(485, 80)

$btnExtractBIOS = New-Object System.Windows.Forms.Button
$btnExtractBIOS.Text = "Extract Current BIOS"
$btnExtractBIOS.Location = New-Object System.Drawing.Point(10, 30)
$btnExtractBIOS.Size = New-Object System.Drawing.Size(150, 35)

$btnImportConfig = New-Object System.Windows.Forms.Button
$btnImportConfig.Text = "Import Config File"
$btnImportConfig.Location = New-Object System.Drawing.Point(170, 30)
$btnImportConfig.Size = New-Object System.Drawing.Size(150, 35)

$btnOpenConfigs = New-Object System.Windows.Forms.Button
$btnOpenConfigs.Text = "Open Configs Folder"
$btnOpenConfigs.Location = New-Object System.Drawing.Point(330, 30)
$btnOpenConfigs.Size = New-Object System.Drawing.Size(140, 35)

$grpExtract.Controls.AddRange(@($btnExtractBIOS, $btnImportConfig, $btnOpenConfigs))

# Configs List Group
$grpConfigs = New-Object System.Windows.Forms.GroupBox
$grpConfigs.Text = "Saved Configurations"
$grpConfigs.Location = New-Object System.Drawing.Point(10, 210)
$grpConfigs.Size = New-Object System.Drawing.Size(485, 200)

$lstConfigs = New-Object System.Windows.Forms.ListView
$lstConfigs.Location = New-Object System.Drawing.Point(10, 25)
$lstConfigs.Size = New-Object System.Drawing.Size(350, 160)
$lstConfigs.View = "Details"
$lstConfigs.FullRowSelect = $true
$lstConfigs.GridLines = $true
$lstConfigs.Columns.Add("Manufacturer", 80) | Out-Null
$lstConfigs.Columns.Add("Config File", 180) | Out-Null
$lstConfigs.Columns.Add("Default", 60) | Out-Null

$btnSetDefault = New-Object System.Windows.Forms.Button
$btnSetDefault.Text = "Set as Default"
$btnSetDefault.Location = New-Object System.Drawing.Point(370, 25)
$btnSetDefault.Size = New-Object System.Drawing.Size(100, 30)

$btnDeleteConfig = New-Object System.Windows.Forms.Button
$btnDeleteConfig.Text = "Delete"
$btnDeleteConfig.Location = New-Object System.Drawing.Point(370, 60)
$btnDeleteConfig.Size = New-Object System.Drawing.Size(100, 30)

$btnRefreshConfigs = New-Object System.Windows.Forms.Button
$btnRefreshConfigs.Text = "Refresh List"
$btnRefreshConfigs.Location = New-Object System.Drawing.Point(370, 95)
$btnRefreshConfigs.Size = New-Object System.Drawing.Size(100, 30)

$grpConfigs.Controls.AddRange(@($lstConfigs, $btnSetDefault, $btnDeleteConfig, $btnRefreshConfigs))

$tabBIOS.Controls.AddRange(@($grpSysInfo, $grpExtract, $grpConfigs))
#endregion

#region Downloads Tab
$tabDownloads = New-Object System.Windows.Forms.TabPage
$tabDownloads.Text = "Downloads"
$tabDownloads.Padding = New-Object System.Windows.Forms.Padding(10)

# BIOS Tools Group
$grpBIOSTools = New-Object System.Windows.Forms.GroupBox
$grpBIOSTools.Text = "BIOS Configuration Tools"
$grpBIOSTools.Location = New-Object System.Drawing.Point(10, 10)
$grpBIOSTools.Size = New-Object System.Drawing.Size(485, 180)

$btnDownloadDell = New-Object System.Windows.Forms.Button
$btnDownloadDell.Text = "Download Dell CCTK"
$btnDownloadDell.Location = New-Object System.Drawing.Point(10, 30)
$btnDownloadDell.Size = New-Object System.Drawing.Size(220, 35)

$lblDellDesc = New-Object System.Windows.Forms.Label
$lblDellDesc.Text = "Dell Command Configure"
$lblDellDesc.Location = New-Object System.Drawing.Point(240, 38)
$lblDellDesc.Size = New-Object System.Drawing.Size(230, 20)
$lblDellDesc.ForeColor = [System.Drawing.Color]::Gray

$btnDownloadHP = New-Object System.Windows.Forms.Button
$btnDownloadHP.Text = "Download HP BCU"
$btnDownloadHP.Location = New-Object System.Drawing.Point(10, 75)
$btnDownloadHP.Size = New-Object System.Drawing.Size(220, 35)

$lblHPDesc = New-Object System.Windows.Forms.Label
$lblHPDesc.Text = "HP BIOS Configuration Utility"
$lblHPDesc.Location = New-Object System.Drawing.Point(240, 83)
$lblHPDesc.Size = New-Object System.Drawing.Size(230, 20)
$lblHPDesc.ForeColor = [System.Drawing.Color]::Gray

$btnDownloadLenovo = New-Object System.Windows.Forms.Button
$btnDownloadLenovo.Text = "Download Lenovo Tool"
$btnDownloadLenovo.Location = New-Object System.Drawing.Point(10, 120)
$btnDownloadLenovo.Size = New-Object System.Drawing.Size(220, 35)

$lblLenovoDesc = New-Object System.Windows.Forms.Label
$lblLenovoDesc.Text = "Think BIOS Config Tool"
$lblLenovoDesc.Location = New-Object System.Drawing.Point(240, 128)
$lblLenovoDesc.Size = New-Object System.Drawing.Size(230, 20)
$lblLenovoDesc.ForeColor = [System.Drawing.Color]::Gray

$grpBIOSTools.Controls.AddRange(@($btnDownloadDell, $lblDellDesc, $btnDownloadHP, $lblHPDesc, $btnDownloadLenovo, $lblLenovoDesc))

# Windows ADK Group
$grpADKDownload = New-Object System.Windows.Forms.GroupBox
$grpADKDownload.Text = "Windows ADK"
$grpADKDownload.Location = New-Object System.Drawing.Point(10, 200)
$grpADKDownload.Size = New-Object System.Drawing.Size(485, 100)

$btnDownloadADK = New-Object System.Windows.Forms.Button
$btnDownloadADK.Text = "Download Windows ADK"
$btnDownloadADK.Location = New-Object System.Drawing.Point(10, 30)
$btnDownloadADK.Size = New-Object System.Drawing.Size(220, 35)

$lblADKDesc = New-Object System.Windows.Forms.Label
$lblADKDesc.Text = "Required for creating WinPE USB drives"
$lblADKDesc.Location = New-Object System.Drawing.Point(240, 38)
$lblADKDesc.Size = New-Object System.Drawing.Size(230, 20)
$lblADKDesc.ForeColor = [System.Drawing.Color]::Gray

$btnDownloadWinPE = New-Object System.Windows.Forms.Button
$btnDownloadWinPE.Text = "Download WinPE Add-on"
$btnDownloadWinPE.Location = New-Object System.Drawing.Point(10, 70)
$btnDownloadWinPE.Size = New-Object System.Drawing.Size(220, 25)
$btnDownloadWinPE.Font = New-Object System.Drawing.Font("Segoe UI", 8)

$grpADKDownload.Controls.AddRange(@($btnDownloadADK, $lblADKDesc, $btnDownloadWinPE))

# Tools Folder Group
$grpToolsFolder = New-Object System.Windows.Forms.GroupBox
$grpToolsFolder.Text = "Tools Location"
$grpToolsFolder.Location = New-Object System.Drawing.Point(10, 310)
$grpToolsFolder.Size = New-Object System.Drawing.Size(485, 80)

$lblToolsPath = New-Object System.Windows.Forms.Label
$lblToolsPath.Text = "Tools folder: $script:ToolsPath"
$lblToolsPath.Location = New-Object System.Drawing.Point(10, 25)
$lblToolsPath.Size = New-Object System.Drawing.Size(460, 20)

$btnOpenTools = New-Object System.Windows.Forms.Button
$btnOpenTools.Text = "Open Tools Folder"
$btnOpenTools.Location = New-Object System.Drawing.Point(10, 48)
$btnOpenTools.Size = New-Object System.Drawing.Size(150, 25)

$grpToolsFolder.Controls.AddRange(@($lblToolsPath, $btnOpenTools))

$tabDownloads.Controls.AddRange(@($grpBIOSTools, $grpADKDownload, $grpToolsFolder))
#endregion

# Add tabs to tab control
$tabControl.TabPages.AddRange(@($tabUSB, $tabBIOS, $tabDownloads))

#region Status Bar and Progress
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 500)
$progressBar.Size = New-Object System.Drawing.Size(515, 25)
$progressBar.Style = "Continuous"

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready"
$lblStatus.Location = New-Object System.Drawing.Point(10, 530)
$lblStatus.Size = New-Object System.Drawing.Size(515, 40)
$lblStatus.BorderStyle = "Fixed3D"

# Version label
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "QuickPXE v1.0"
$lblVersion.Location = New-Object System.Drawing.Point(10, 575)
$lblVersion.Size = New-Object System.Drawing.Size(100, 20)
$lblVersion.ForeColor = [System.Drawing.Color]::Gray
#endregion

# Add controls to form
$mainForm.Controls.AddRange(@($tabControl, $progressBar, $lblStatus, $lblVersion))

#region Helper Functions
function Update-Status {
    param([string]$Message)
    $lblStatus.Text = $Message
    $lblStatus.Refresh()
}

function Update-Progress {
    param([int]$Value)
    $progressBar.Value = [Math]::Min($Value, 100)
    $progressBar.Refresh()
}

function Update-USBDrives {
    $cmbDrive.Items.Clear()
    $drives = Get-USBDrives
    
    if ($drives.Count -eq 0) {
        $cmbDrive.Items.Add("No USB drives found")
        $cmbDrive.SelectedIndex = 0
        $btnCreateUSB.Enabled = $false
        $btnUpdateUSB.Enabled = $false
    }
    else {
        foreach ($drive in $drives) {
            $cmbDrive.Items.Add($drive.FriendlyName)
        }
        $cmbDrive.SelectedIndex = 0
        $btnCreateUSB.Enabled = $true
        $btnUpdateUSB.Enabled = $true
        $script:USBDrives = $drives
    }
}

function Test-ADKStatus {
    $adkInfo = Test-ADKInstalled
    
    if ($adkInfo.ADKInstalled) {
        $lblADKStatus.Text = "ADK: Installed"
        $lblADKStatus.ForeColor = [System.Drawing.Color]::Green
    }
    else {
        $lblADKStatus.Text = "ADK: Not Installed"
        $lblADKStatus.ForeColor = [System.Drawing.Color]::Red
        $btnInstallADK.Enabled = $true
    }
    
    if ($adkInfo.WinPEInstalled) {
        $lblWinPEStatus.Text = "WinPE Add-on: Installed"
        $lblWinPEStatus.ForeColor = [System.Drawing.Color]::Green
    }
    else {
        $lblWinPEStatus.Text = "WinPE Add-on: Not Installed"
        $lblWinPEStatus.ForeColor = [System.Drawing.Color]::Red
        $btnInstallADK.Enabled = $true
    }
    
    # Enable/disable Create button based on ADK status
    $btnCreateUSB.Enabled = $adkInfo.ADKInstalled -and $adkInfo.WinPEInstalled -and ($cmbDrive.Items.Count -gt 0 -and $cmbDrive.Items[0] -ne "No USB drives found")
}

function Update-SystemInfo {
    try {
        $sysInfo = Get-SystemInfo
        $lblManufacturer.Text = "Manufacturer: $($sysInfo.Manufacturer)"
        $lblModel.Text = "Model: $($sysInfo.Model)"
        $lblSerial.Text = "Serial: $($sysInfo.SerialNumber)"
    }
    catch {
        $lblManufacturer.Text = "Manufacturer: Unknown"
        $lblModel.Text = "Model: Unknown"
        $lblSerial.Text = "Serial: Unknown"
    }
}

function Update-ConfigsList {
    $lstConfigs.Items.Clear()
    
    $configs = Get-BIOSConfigs -ConfigsPath $script:ConfigsPath
    
    foreach ($config in $configs) {
        $item = New-Object System.Windows.Forms.ListViewItem($config.Manufacturer)
        $item.SubItems.Add($config.FileName) | Out-Null
        $item.SubItems.Add($(if ($config.IsDefault) { "Yes" } else { "" })) | Out-Null
        $item.Tag = $config.FullPath
        $lstConfigs.Items.Add($item) | Out-Null
    }
}

function Get-SelectedDriveLetter {
    if ($cmbDrive.SelectedIndex -lt 0 -or $cmbDrive.Items[0] -eq "No USB drives found") {
        return $null
    }
    return $script:USBDrives[$cmbDrive.SelectedIndex].DriveLetter
}
#endregion

#region Event Handlers

# Refresh USB drives button
$btnRefresh.Add_Click({
    Update-Status "Scanning for USB drives..."
    Update-USBDrives
    Test-ADKStatus
    Update-Status "Ready"
})

# Install ADK button
$btnInstallADK.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "This will download and install Windows ADK and WinPE add-on.`n`nThis may take 10-20 minutes and requires an internet connection.`n`nContinue?",
        "Install Windows ADK",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Update-Status "Downloading and installing Windows ADK..."
        $progressBar.Style = "Marquee"
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        
        try {
            $success = Install-WindowsADK -Silent
            if ($success) {
                [System.Windows.Forms.MessageBox]::Show("Windows ADK installed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                Test-ADKStatus
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to install ADK: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            $progressBar.Style = "Continuous"
            $progressBar.Value = 0
            $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
            Update-Status "Ready"
        }
    }
})

# Create USB button
$btnCreateUSB.Add_Click({
    $driveLetter = Get-SelectedDriveLetter
    if (-not $driveLetter) {
        [System.Windows.Forms.MessageBox]::Show("Please select a USB drive.", "No Drive Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "WARNING: All data on drive $driveLetter will be ERASED!`n`nAre you sure you want to create a WinPE USB on this drive?",
        "Confirm Format",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Update-Status "Creating WinPE USB on $driveLetter..."
        $progressBar.Style = "Marquee"
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnCreateUSB.Enabled = $false
        $btnUpdateUSB.Enabled = $false
        
        try {
            $success = New-WinPEUSB -DriveLetter $driveLetter -ConfigsPath $script:ConfigsPath -ToolsPath $script:ToolsPath -StartnetPath $script:StartnetPath
            
            if ($success) {
                [System.Windows.Forms.MessageBox]::Show("WinPE USB created successfully!`n`nYou can now boot from this USB to configure BIOS settings.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to create USB: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            $progressBar.Style = "Continuous"
            $progressBar.Value = 0
            $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
            $btnCreateUSB.Enabled = $true
            $btnUpdateUSB.Enabled = $true
            Update-Status "Ready"
        }
    }
})

# Update USB button
$btnUpdateUSB.Add_Click({
    $driveLetter = Get-SelectedDriveLetter
    if (-not $driveLetter) {
        [System.Windows.Forms.MessageBox]::Show("Please select a USB drive.", "No Drive Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    Update-Status "Updating WinPE USB on $driveLetter..."
    $progressBar.Style = "Marquee"
    $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $btnCreateUSB.Enabled = $false
    $btnUpdateUSB.Enabled = $false
    
    try {
        $success = Update-WinPEUSB -DriveLetter $driveLetter -ConfigsPath $script:ConfigsPath -ToolsPath $script:ToolsPath -StartnetPath $script:StartnetPath
        
        if ($success) {
            [System.Windows.Forms.MessageBox]::Show("WinPE USB updated successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to update USB: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $progressBar.Style = "Continuous"
        $progressBar.Value = 0
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
        $btnCreateUSB.Enabled = $true
        $btnUpdateUSB.Enabled = $true
        Update-Status "Ready"
    }
})

# Extract BIOS button
$btnExtractBIOS.Add_Click({
    Update-Status "Extracting BIOS configuration..."
    $progressBar.Style = "Marquee"
    $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    
    try {
        $outputFile = Export-BIOSConfig -OutputPath $script:ConfigsPath -ToolsPath $script:ToolsPath
        [System.Windows.Forms.MessageBox]::Show("BIOS configuration exported to:`n$outputFile", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        Update-ConfigsList
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to extract BIOS config: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $progressBar.Style = "Continuous"
        $progressBar.Value = 0
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
        Update-Status "Ready"
    }
})

# Import Config button
$btnImportConfig.Add_Click({
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Title = "Select BIOS Configuration File"
    $openDialog.Filter = "BIOS Config Files (*.cctk;*.REPSET;*.ini)|*.cctk;*.REPSET;*.ini|All Files (*.*)|*.*"
    
    if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $imported = Import-BIOSConfig -SourceFile $openDialog.FileName -ConfigsPath $script:ConfigsPath
            [System.Windows.Forms.MessageBox]::Show("Configuration imported to:`n$imported", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            Update-ConfigsList
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to import config: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# Open Configs Folder button
$btnOpenConfigs.Add_Click({
    if (-not (Test-Path $script:ConfigsPath)) {
        New-Item -ItemType Directory -Path $script:ConfigsPath -Force | Out-Null
    }
    Start-Process explorer.exe -ArgumentList $script:ConfigsPath
})

# Set as Default button
$btnSetDefault.Add_Click({
    if ($lstConfigs.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a configuration file.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $configPath = $lstConfigs.SelectedItems[0].Tag
    try {
        Set-DefaultBIOSConfig -ConfigFile $configPath
        [System.Windows.Forms.MessageBox]::Show("Configuration set as default.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        Update-ConfigsList
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to set default: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Delete Config button
$btnDeleteConfig.Add_Click({
    if ($lstConfigs.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a configuration file.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $configPath = $lstConfigs.SelectedItems[0].Tag
    $result = [System.Windows.Forms.MessageBox]::Show("Delete this configuration file?`n$configPath", "Confirm Delete", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Remove-Item -Path $configPath -Force
        Update-ConfigsList
    }
})

# Refresh Configs button
$btnRefreshConfigs.Add_Click({
    Update-ConfigsList
})

# Download buttons
$btnDownloadDell.Add_Click({
    Start-Process "https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure"
})

$btnDownloadHP.Add_Click({
    Start-Process "https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html"
})

$btnDownloadLenovo.Add_Click({
    Start-Process "https://support.lenovo.com/solutions/ht100612"
})

$btnDownloadADK.Add_Click({
    $urls = Get-ADKDownloadUrls
    Start-Process $urls.ADK
})

$btnDownloadWinPE.Add_Click({
    $urls = Get-ADKDownloadUrls
    Start-Process $urls.WinPE
})

$btnOpenTools.Add_Click({
    if (-not (Test-Path $script:ToolsPath)) {
        New-Item -ItemType Directory -Path $script:ToolsPath -Force | Out-Null
    }
    Start-Process explorer.exe -ArgumentList $script:ToolsPath
})

# Form Load event
$mainForm.Add_Shown({
    Update-Status "Initializing..."
    Update-USBDrives
    Test-ADKStatus
    Update-SystemInfo
    Update-ConfigsList
    Update-Status "Ready"
})

#endregion

# Show the form
[void]$mainForm.ShowDialog()
