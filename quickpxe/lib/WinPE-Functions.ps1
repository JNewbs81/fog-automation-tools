# WinPE-Functions.ps1
# WinPE creation and update functions for QuickPXE

function New-WinPEWorkingDirectory {
    <#
    .SYNOPSIS
    Creates a WinPE working directory using copype
    .PARAMETER Architecture
    amd64 or x86 (default: amd64)
    .PARAMETER WorkingPath
    Path to create the WinPE working directory
    #>
    param(
        [ValidateSet("amd64", "x86")]
        [string]$Architecture = "amd64",
        
        [string]$WorkingPath = "$env:TEMP\WinPE_$Architecture"
    )
    
    # Get ADK path
    $adkInfo = Test-ADKInstalled
    if (-not $adkInfo.ADKInstalled -or -not $adkInfo.WinPEInstalled) {
        throw "Windows ADK and WinPE add-on must be installed"
    }
    
    # Remove existing working directory
    if (Test-Path $WorkingPath) {
        Write-Host "Removing existing working directory..."
        Remove-Item -Path $WorkingPath -Recurse -Force
    }
    
    # Set up environment and run copype
    $deployToolsPath = $adkInfo.DeploymentTools
    $copypeCmd = Join-Path $deployToolsPath "copype.cmd"
    
    if (-not (Test-Path $copypeCmd)) {
        # Try alternate location
        $copypeCmd = Join-Path $deployToolsPath "amd64\copype.cmd"
    }
    
    Write-Host "Creating WinPE working directory at $WorkingPath..."
    
    # Create a batch file to set environment and run copype
    $batchContent = @"
@echo off
call "$deployToolsPath\DandISetEnv.bat"
copype $Architecture "$WorkingPath"
"@
    
    $batchFile = "$env:TEMP\run_copype.bat"
    $batchContent | Out-File -FilePath $batchFile -Encoding ASCII
    
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batchFile`"" -Wait -PassThru -NoNewWindow
    
    Remove-Item $batchFile -Force -ErrorAction SilentlyContinue
    
    if ($process.ExitCode -ne 0) {
        throw "copype failed with exit code: $($process.ExitCode)"
    }
    
    if (-not (Test-Path (Join-Path $WorkingPath "media\sources\boot.wim"))) {
        throw "WinPE working directory creation failed - boot.wim not found"
    }
    
    Write-Host "WinPE working directory created successfully." -ForegroundColor Green
    return $WorkingPath
}

function Mount-WinPEImage {
    <#
    .SYNOPSIS
    Mounts a WinPE boot.wim for modification
    .PARAMETER WimPath
    Path to the boot.wim file
    .PARAMETER MountPath
    Path to mount the WIM to
    .PARAMETER Index
    WIM image index (default: 1)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$WimPath,
        
        [string]$MountPath = "C:\WinPE-Mount",
        
        [int]$Index = 1
    )
    
    # Create mount directory
    if (-not (Test-Path $MountPath)) {
        New-Item -ItemType Directory -Path $MountPath -Force | Out-Null
    }
    
    # Check if already mounted
    $mounted = Get-WindowsImage -Mounted | Where-Object { $_.MountPath -eq $MountPath }
    if ($mounted) {
        Write-Host "Image already mounted at $MountPath. Unmounting first..."
        Dismount-WindowsImage -Path $MountPath -Discard
    }
    
    Write-Host "Mounting WinPE image..."
    
    try {
        Mount-WindowsImage -ImagePath $WimPath -Index $Index -Path $MountPath
        Write-Host "WinPE image mounted at $MountPath" -ForegroundColor Green
        return $MountPath
    }
    catch {
        throw "Failed to mount WinPE image: $_"
    }
}

function Dismount-WinPEImage {
    <#
    .SYNOPSIS
    Unmounts a WinPE image, optionally saving changes
    .PARAMETER MountPath
    Path where the WIM is mounted
    .PARAMETER Save
    If true, saves changes. If false, discards changes.
    #>
    param(
        [string]$MountPath = "C:\WinPE-Mount",
        [switch]$Save
    )
    
    Write-Host "Unmounting WinPE image..."
    
    try {
        if ($Save) {
            Dismount-WindowsImage -Path $MountPath -Save
            Write-Host "WinPE image unmounted and changes saved." -ForegroundColor Green
        }
        else {
            Dismount-WindowsImage -Path $MountPath -Discard
            Write-Host "WinPE image unmounted (changes discarded)." -ForegroundColor Yellow
        }
        
        # Clean up mount directory
        if (Test-Path $MountPath) {
            Remove-Item -Path $MountPath -Force -ErrorAction SilentlyContinue
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to unmount WinPE image: $_"
        return $false
    }
}

function Add-FilesToWinPE {
    <#
    .SYNOPSIS
    Adds files to a mounted WinPE image
    .PARAMETER MountPath
    Path where the WIM is mounted
    .PARAMETER SourcePath
    Path to the source files/folder
    .PARAMETER DestinationPath
    Destination path within the WinPE image (relative to mount point)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MountPath,
        
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )
    
    $fullDestPath = Join-Path $MountPath $DestinationPath
    
    # Create destination directory if needed
    $destDir = Split-Path $fullDestPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    
    Write-Host "Copying $SourcePath to $DestinationPath..."
    
    if (Test-Path $SourcePath -PathType Container) {
        # Copy directory
        Copy-Item -Path $SourcePath -Destination $fullDestPath -Recurse -Force
    }
    else {
        # Copy file
        Copy-Item -Path $SourcePath -Destination $fullDestPath -Force
    }
    
    Write-Host "Files copied successfully." -ForegroundColor Green
}

function New-WinPEUSB {
    <#
    .SYNOPSIS
    Creates a complete WinPE USB drive with BIOS tools
    .PARAMETER DriveLetter
    Target USB drive letter
    .PARAMETER ConfigsPath
    Path to the configs folder with BIOS configurations
    .PARAMETER ToolsPath
    Path to the BIOS tools folder
    .PARAMETER StartnetPath
    Path to the custom startnet.cmd
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,
        
        [Parameter(Mandatory=$true)]
        [string]$ConfigsPath,
        
        [Parameter(Mandatory=$true)]
        [string]$ToolsPath,
        
        [Parameter(Mandatory=$true)]
        [string]$StartnetPath
    )
    
    $DriveLetter = $DriveLetter.TrimEnd(':')
    
    Write-Host "Creating WinPE USB on drive $DriveLetter..." -ForegroundColor Cyan
    
    # Step 1: Create WinPE working directory
    $workingPath = New-WinPEWorkingDirectory -Architecture "amd64"
    
    # Step 2: Mount the boot.wim
    $wimPath = Join-Path $workingPath "media\sources\boot.wim"
    $mountPath = "C:\WinPE-Mount"
    Mount-WinPEImage -WimPath $wimPath -MountPath $mountPath
    
    try {
        # Step 3: Copy startnet.cmd
        Write-Host "Adding custom startnet.cmd..."
        Copy-Item -Path $StartnetPath -Destination "$mountPath\Windows\System32\startnet.cmd" -Force
        
        # Step 4: Copy BIOS tools
        if (Test-Path $ToolsPath) {
            Write-Host "Adding BIOS tools..."
            $toolsDest = "$mountPath\bios-tools"
            if (-not (Test-Path $toolsDest)) {
                New-Item -ItemType Directory -Path $toolsDest -Force | Out-Null
            }
            Copy-Item -Path "$ToolsPath\*" -Destination $toolsDest -Recurse -Force
        }
        
        # Step 5: Copy configs
        if (Test-Path $ConfigsPath) {
            Write-Host "Adding BIOS configs..."
            $configsDest = "$mountPath\configs"
            if (-not (Test-Path $configsDest)) {
                New-Item -ItemType Directory -Path $configsDest -Force | Out-Null
            }
            Copy-Item -Path "$ConfigsPath\*" -Destination $configsDest -Recurse -Force
        }
        
        # Step 6: Unmount and save
        Dismount-WinPEImage -MountPath $mountPath -Save
        
        # Step 7: Format USB drive
        Write-Host "Formatting USB drive..."
        Format-USBDrive -DriveLetter $DriveLetter -Label "QUICKPXE" -FileSystem "FAT32"
        
        # Step 8: Copy WinPE files to USB
        Write-Host "Copying WinPE files to USB..."
        $mediaPath = Join-Path $workingPath "media"
        Copy-Item -Path "$mediaPath\*" -Destination "$DriveLetter`:" -Recurse -Force
        
        Write-Host "WinPE USB created successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to create WinPE USB: $_"
        
        # Try to clean up
        Dismount-WinPEImage -MountPath $mountPath -Save:$false
        return $false
    }
    finally {
        # Clean up working directory
        if (Test-Path $workingPath) {
            Remove-Item -Path $workingPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Update-WinPEUSB {
    <#
    .SYNOPSIS
    Updates an existing WinPE USB drive with new configs and scripts
    .PARAMETER DriveLetter
    Target USB drive letter
    .PARAMETER ConfigsPath
    Path to the configs folder with BIOS configurations
    .PARAMETER ToolsPath
    Path to the BIOS tools folder (optional)
    .PARAMETER StartnetPath
    Path to the custom startnet.cmd
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,
        
        [string]$ConfigsPath,
        
        [string]$ToolsPath,
        
        [Parameter(Mandatory=$true)]
        [string]$StartnetPath
    )
    
    $DriveLetter = $DriveLetter.TrimEnd(':') + ":"
    
    # Verify this is a WinPE USB
    $wimPath = "$DriveLetter\sources\boot.wim"
    if (-not (Test-Path $wimPath)) {
        throw "Not a valid WinPE USB - boot.wim not found at $wimPath"
    }
    
    Write-Host "Updating WinPE USB on drive $DriveLetter..." -ForegroundColor Cyan
    
    # Mount the boot.wim
    $mountPath = "C:\WinPE-Mount"
    Mount-WinPEImage -WimPath $wimPath -MountPath $mountPath
    
    try {
        # Update startnet.cmd
        Write-Host "Updating startnet.cmd..."
        Copy-Item -Path $StartnetPath -Destination "$mountPath\Windows\System32\startnet.cmd" -Force
        
        # Update BIOS tools if provided
        if ($ToolsPath -and (Test-Path $ToolsPath)) {
            Write-Host "Updating BIOS tools..."
            $toolsDest = "$mountPath\bios-tools"
            if (Test-Path $toolsDest) {
                Remove-Item -Path $toolsDest -Recurse -Force
            }
            New-Item -ItemType Directory -Path $toolsDest -Force | Out-Null
            Copy-Item -Path "$ToolsPath\*" -Destination $toolsDest -Recurse -Force
        }
        
        # Update configs if provided
        if ($ConfigsPath -and (Test-Path $ConfigsPath)) {
            Write-Host "Updating BIOS configs..."
            $configsDest = "$mountPath\configs"
            if (Test-Path $configsDest) {
                Remove-Item -Path $configsDest -Recurse -Force
            }
            New-Item -ItemType Directory -Path $configsDest -Force | Out-Null
            Copy-Item -Path "$ConfigsPath\*" -Destination $configsDest -Recurse -Force
        }
        
        # Unmount and save
        Dismount-WinPEImage -MountPath $mountPath -Save
        
        Write-Host "WinPE USB updated successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to update WinPE USB: $_"
        Dismount-WinPEImage -MountPath $mountPath -Save:$false
        return $false
    }
}

Export-ModuleMember -Function New-WinPEWorkingDirectory, Mount-WinPEImage, Dismount-WinPEImage, Add-FilesToWinPE, New-WinPEUSB, Update-WinPEUSB
