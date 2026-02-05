# BIOS-Functions.ps1
# BIOS extraction and import functions for QuickPXE

function Get-SystemManufacturer {
    <#
    .SYNOPSIS
    Gets the system manufacturer (Dell, HP, Lenovo, etc.)
    #>
    
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    
    # Normalize manufacturer names
    if ($manufacturer -match "Dell") {
        return "Dell"
    }
    elseif ($manufacturer -match "HP|Hewlett") {
        return "HP"
    }
    elseif ($manufacturer -match "Lenovo") {
        return "Lenovo"
    }
    else {
        return $manufacturer
    }
}

function Get-SystemModel {
    <#
    .SYNOPSIS
    Gets the system model and returns a normalized filename-friendly version
    .OUTPUTS
    Object with Model (original) and NormalizedModel (filename-friendly)
    #>
    
    $model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
    
    # Normalize for filename: lowercase, replace spaces with hyphens, remove special chars
    $normalized = $model.ToLower() -replace '\s+', '-' -replace '[^a-z0-9\-]', ''
    
    return [PSCustomObject]@{
        Model           = $model
        NormalizedModel = $normalized
    }
}

function Get-SystemInfo {
    <#
    .SYNOPSIS
    Gets complete system information for BIOS operations
    #>
    
    $bios = Get-CimInstance -ClassName Win32_BIOS
    
    $manufacturer = Get-SystemManufacturer
    $modelInfo = Get-SystemModel
    
    return [PSCustomObject]@{
        Manufacturer    = $manufacturer
        Model           = $modelInfo.Model
        NormalizedModel = $modelInfo.NormalizedModel
        SerialNumber    = $bios.SerialNumber
        BIOSVersion     = $bios.SMBIOSBIOSVersion
        BIOSDate        = $bios.ReleaseDate
    }
}

function Export-BIOSConfig {
    <#
    .SYNOPSIS
    Exports the current system's BIOS configuration
    .PARAMETER OutputPath
    Path to save the exported config (folder path, filename will be auto-generated)
    .PARAMETER ToolsPath
    Path to the BIOS tools folder
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$true)]
        [string]$ToolsPath
    )
    
    $sysInfo = Get-SystemInfo
    $manufacturer = $sysInfo.Manufacturer
    $modelName = $sysInfo.NormalizedModel
    
    Write-Host "System: $manufacturer $($sysInfo.Model)" -ForegroundColor Cyan
    Write-Host "Exporting BIOS configuration..."
    
    # Create manufacturer folder if needed
    $mfgFolder = Join-Path $OutputPath $manufacturer.ToLower()
    if (-not (Test-Path $mfgFolder)) {
        New-Item -ItemType Directory -Path $mfgFolder -Force | Out-Null
    }
    
    switch ($manufacturer) {
        "Dell" {
            $cctkPath = Join-Path $ToolsPath "dell\cctk.exe"
            if (-not (Test-Path $cctkPath)) {
                throw "Dell CCTK not found at $cctkPath"
            }
            
            $outputFile = Join-Path $mfgFolder "$modelName.cctk"
            
            Write-Host "Using Dell CCTK to export config..."
            $result = & $cctkPath --outfile="$outputFile" 2>&1
            
            if ($LASTEXITCODE -eq 0 -or (Test-Path $outputFile)) {
                Write-Host "BIOS config exported to: $outputFile" -ForegroundColor Green
                return $outputFile
            }
            else {
                throw "CCTK export failed: $result"
            }
        }
        
        "HP" {
            $bcuPath = Join-Path $ToolsPath "hp\BiosConfigUtility64.exe"
            if (-not (Test-Path $bcuPath)) {
                $bcuPath = Join-Path $ToolsPath "hp\BiosConfigUtility.exe"
            }
            if (-not (Test-Path $bcuPath)) {
                throw "HP BCU not found in $ToolsPath\hp"
            }
            
            $outputFile = Join-Path $mfgFolder "$modelName.REPSET"
            
            Write-Host "Using HP BCU to export config..."
            $result = & $bcuPath /get:"$outputFile" 2>&1
            
            if ($LASTEXITCODE -eq 0 -or (Test-Path $outputFile)) {
                Write-Host "BIOS config exported to: $outputFile" -ForegroundColor Green
                return $outputFile
            }
            else {
                throw "BCU export failed: $result"
            }
        }
        
        "Lenovo" {
            # Lenovo uses WMI for BIOS settings export
            $outputFile = Join-Path $mfgFolder "$modelName.ini"
            
            Write-Host "Exporting Lenovo BIOS settings via WMI..."
            
            try {
                $settings = Get-CimInstance -Namespace "root\wmi" -ClassName "Lenovo_BiosSetting" -ErrorAction Stop
                
                $iniContent = @()
                $iniContent += "[BIOSConfig]"
                $iniContent += "; Exported from $($sysInfo.Model) on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                $iniContent += ""
                
                foreach ($setting in $settings) {
                    if ($setting.CurrentSetting -and $setting.CurrentSetting -ne "") {
                        # Format: SettingName,CurrentValue,PossibleValues
                        $parts = $setting.CurrentSetting -split ','
                        if ($parts.Count -ge 2) {
                            $iniContent += "$($parts[0])=$($parts[1])"
                        }
                    }
                }
                
                $iniContent | Out-File -FilePath $outputFile -Encoding UTF8
                
                Write-Host "BIOS config exported to: $outputFile" -ForegroundColor Green
                return $outputFile
            }
            catch {
                throw "Failed to export Lenovo BIOS settings: $_"
            }
        }
        
        default {
            throw "Unsupported manufacturer: $manufacturer"
        }
    }
}

function Import-BIOSConfig {
    <#
    .SYNOPSIS
    Imports a BIOS config file to the configs folder
    .PARAMETER SourceFile
    Path to the config file to import
    .PARAMETER ConfigsPath
    Path to the configs folder
    .PARAMETER SetAsDefault
    If true, also copies the file as default config
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceFile,
        
        [Parameter(Mandatory=$true)]
        [string]$ConfigsPath,
        
        [switch]$SetAsDefault
    )
    
    if (-not (Test-Path $SourceFile)) {
        throw "Source file not found: $SourceFile"
    }
    
    $extension = [System.IO.Path]::GetExtension($SourceFile).ToLower()
    $fileName = [System.IO.Path]::GetFileName($SourceFile)
    
    # Determine manufacturer from file extension
    $manufacturer = switch ($extension) {
        ".cctk" { "dell" }
        ".repset" { "hp" }
        ".ini" { "lenovo" }
        default { throw "Unknown config file type: $extension" }
    }
    
    # Create manufacturer folder
    $mfgFolder = Join-Path $ConfigsPath $manufacturer
    if (-not (Test-Path $mfgFolder)) {
        New-Item -ItemType Directory -Path $mfgFolder -Force | Out-Null
    }
    
    # Copy file
    $destFile = Join-Path $mfgFolder $fileName
    Copy-Item -Path $SourceFile -Destination $destFile -Force
    Write-Host "Config imported to: $destFile" -ForegroundColor Green
    
    # Set as default if requested
    if ($SetAsDefault) {
        $defaultFile = Join-Path $mfgFolder "default$extension"
        Copy-Item -Path $SourceFile -Destination $defaultFile -Force
        Write-Host "Also set as default: $defaultFile" -ForegroundColor Green
    }
    
    return $destFile
}

function Get-BIOSConfigs {
    <#
    .SYNOPSIS
    Gets a list of all BIOS configs in the configs folder
    .PARAMETER ConfigsPath
    Path to the configs folder
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigsPath
    )
    
    $configs = @()
    
    foreach ($mfg in @("dell", "hp", "lenovo")) {
        $mfgPath = Join-Path $ConfigsPath $mfg
        if (Test-Path $mfgPath) {
            $files = Get-ChildItem -Path $mfgPath -File
            foreach ($file in $files) {
                $isDefault = $file.BaseName -eq "default"
                $configs += [PSCustomObject]@{
                    Manufacturer = $mfg
                    FileName     = $file.Name
                    FullPath     = $file.FullName
                    IsDefault    = $isDefault
                    DisplayName  = "$mfg/$($file.Name)$(if($isDefault){' (DEFAULT)'})"
                }
            }
        }
    }
    
    return $configs
}

function Set-DefaultBIOSConfig {
    <#
    .SYNOPSIS
    Sets a config file as the default for its manufacturer
    .PARAMETER ConfigFile
    Full path to the config file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigFile
    )
    
    if (-not (Test-Path $ConfigFile)) {
        throw "Config file not found: $ConfigFile"
    }
    
    $extension = [System.IO.Path]::GetExtension($ConfigFile)
    $folder = Split-Path $ConfigFile -Parent
    $defaultFile = Join-Path $folder "default$extension"
    
    Copy-Item -Path $ConfigFile -Destination $defaultFile -Force
    Write-Host "Set as default: $defaultFile" -ForegroundColor Green
    
    return $defaultFile
}

Export-ModuleMember -Function Get-SystemManufacturer, Get-SystemModel, Get-SystemInfo, Export-BIOSConfig, Import-BIOSConfig, Get-BIOSConfigs, Set-DefaultBIOSConfig
