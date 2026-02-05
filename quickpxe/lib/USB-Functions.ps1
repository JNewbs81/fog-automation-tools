# USB-Functions.ps1
# USB drive detection and formatting functions for QuickPXE

function Get-USBDrives {
    <#
    .SYNOPSIS
    Returns a list of removable USB drives
    .OUTPUTS
    Array of objects with DriveLetter, Label, Size, and FriendlyName
    #>
    
    $usbDrives = @()
    
    # Get all removable drives
    $disks = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.MediaType -eq "Removable Media" }
    
    foreach ($disk in $disks) {
        # Get partitions for this disk
        $partitions = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($disk.DeviceID.Replace('\','\\'))'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"
        
        foreach ($partition in $partitions) {
            # Get logical disks (drive letters) for this partition
            $logicalDisks = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition"
            
            foreach ($logicalDisk in $logicalDisks) {
                $sizeGB = [math]::Round($disk.Size / 1GB, 2)
                $freeGB = [math]::Round($logicalDisk.FreeSpace / 1GB, 2)
                
                $usbDrives += [PSCustomObject]@{
                    DriveLetter   = $logicalDisk.DeviceID
                    Label         = if ($logicalDisk.VolumeName) { $logicalDisk.VolumeName } else { "NO LABEL" }
                    SizeGB        = $sizeGB
                    FreeGB        = $freeGB
                    DiskNumber    = $disk.Index
                    FriendlyName  = "$($logicalDisk.DeviceID) - $($logicalDisk.VolumeName) ($sizeGB GB)"
                    Model         = $disk.Model
                }
            }
        }
    }
    
    return $usbDrives
}

function Format-USBDrive {
    <#
    .SYNOPSIS
    Formats a USB drive for WinPE (FAT32 or NTFS based on size)
    .PARAMETER DriveLetter
    The drive letter to format (e.g., "D:")
    .PARAMETER Label
    Volume label for the formatted drive
    .PARAMETER FileSystem
    FAT32 or NTFS (default: FAT32 for UEFI compatibility)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,
        
        [string]$Label = "WINPE",
        
        [ValidateSet("FAT32", "NTFS")]
        [string]$FileSystem = "FAT32"
    )
    
    # Remove trailing colon if present
    $DriveLetter = $DriveLetter.TrimEnd(':')
    
    Write-Host "Formatting drive $DriveLetter as $FileSystem with label $Label..."
    
    # Use diskpart for reliable formatting
    $diskpartScript = @"
select volume $DriveLetter
clean
create partition primary
format fs=$FileSystem label=$Label quick
assign letter=$DriveLetter
active
"@
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    $diskpartScript | Out-File -FilePath $tempFile -Encoding ASCII
    
    try {
        $result = & diskpart /s $tempFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Diskpart failed: $result"
        }
        Write-Host "Format complete." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to format drive: $_"
        return $false
    }
    finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-USBDriveReady {
    <#
    .SYNOPSIS
    Checks if a USB drive is ready and writable
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    
    $DriveLetter = $DriveLetter.TrimEnd(':') + ":"
    
    if (-not (Test-Path $DriveLetter)) {
        return $false
    }
    
    $drive = Get-PSDrive -Name $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
    if (-not $drive) {
        return $false
    }
    
    # Try to create a test file
    $testFile = Join-Path $DriveLetter "quickpxe_test.tmp"
    try {
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item $testFile -Force
        return $true
    }
    catch {
        return $false
    }
}

function Get-USBDriveInfo {
    <#
    .SYNOPSIS
    Gets detailed information about a specific USB drive
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    
    $DriveLetter = $DriveLetter.TrimEnd(':') + ":"
    
    $volume = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $DriveLetter }
    
    if ($volume) {
        return [PSCustomObject]@{
            DriveLetter = $volume.DeviceID
            Label       = $volume.VolumeName
            FileSystem  = $volume.FileSystem
            SizeGB      = [math]::Round($volume.Size / 1GB, 2)
            FreeGB      = [math]::Round($volume.FreeSpace / 1GB, 2)
            UsedGB      = [math]::Round(($volume.Size - $volume.FreeSpace) / 1GB, 2)
        }
    }
    
    return $null
}

Export-ModuleMember -Function Get-USBDrives, Format-USBDrive, Test-USBDriveReady, Get-USBDriveInfo
