# ADK-Functions.ps1
# Windows ADK detection and installation functions for QuickPXE

# ADK download URLs (Windows 11 ADK - works with Win10/11 WinPE)
$script:ADKDownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2243390"
$script:WinPEAddonUrl = "https://go.microsoft.com/fwlink/?linkid=2243391"

function Test-ADKInstalled {
    <#
    .SYNOPSIS
    Checks if Windows ADK and WinPE add-on are installed
    .OUTPUTS
    Object with Installed (bool), ADKPath, WinPEPath, and DeploymentToolsPath
    #>
    
    $result = [PSCustomObject]@{
        ADKInstalled    = $false
        WinPEInstalled  = $false
        ADKPath         = $null
        WinPEPath       = $null
        DeploymentTools = $null
        CopypePath      = $null
    }
    
    # Check common ADK installation paths
    $adkPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit",
        "$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit"
    )
    
    foreach ($path in $adkPaths) {
        if (Test-Path $path) {
            $result.ADKInstalled = $true
            $result.ADKPath = $path
            
            # Check for Deployment Tools
            $deployTools = Join-Path $path "Deployment Tools"
            if (Test-Path $deployTools) {
                $result.DeploymentTools = $deployTools
            }
            
            # Check for WinPE add-on
            $winpePath = Join-Path $path "Windows Preinstallation Environment"
            if (Test-Path $winpePath) {
                $result.WinPEInstalled = $true
                $result.WinPEPath = $winpePath
            }
            
            # Check for copype.cmd
            $copype = Join-Path $deployTools "DandISetEnv.bat"
            if (Test-Path $copype) {
                $result.CopypePath = $deployTools
            }
            
            break
        }
    }
    
    return $result
}

function Get-ADKEnvironmentPath {
    <#
    .SYNOPSIS
    Gets the path to the Deployment and Imaging Tools Environment
    #>
    
    $adkInfo = Test-ADKInstalled
    
    if (-not $adkInfo.ADKInstalled) {
        return $null
    }
    
    # Look for the Deployment Tools environment batch file
    $dandiBat = Join-Path $adkInfo.DeploymentTools "DandISetEnv.bat"
    
    if (Test-Path $dandiBat) {
        return $adkInfo.DeploymentTools
    }
    
    return $null
}

function Install-WindowsADK {
    <#
    .SYNOPSIS
    Downloads and installs Windows ADK and WinPE add-on
    .PARAMETER DownloadPath
    Path to download the installers to
    .PARAMETER Silent
    If true, installs silently without user interaction
    #>
    param(
        [string]$DownloadPath = "$env:TEMP\ADK",
        [switch]$Silent
    )
    
    # Create download directory
    if (-not (Test-Path $DownloadPath)) {
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
    }
    
    $adkInstaller = Join-Path $DownloadPath "adksetup.exe"
    $winpeInstaller = Join-Path $DownloadPath "adkwinpesetup.exe"
    
    Write-Host "Downloading Windows ADK..." -ForegroundColor Cyan
    
    try {
        # Download ADK
        if (-not (Test-Path $adkInstaller)) {
            Write-Host "  Downloading ADK installer..."
            Invoke-WebRequest -Uri $script:ADKDownloadUrl -OutFile $adkInstaller -UseBasicParsing
        }
        
        # Download WinPE add-on
        if (-not (Test-Path $winpeInstaller)) {
            Write-Host "  Downloading WinPE add-on..."
            Invoke-WebRequest -Uri $script:WinPEAddonUrl -OutFile $winpeInstaller -UseBasicParsing
        }
        
        Write-Host "Download complete." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download ADK: $_"
        return $false
    }
    
    # Install ADK
    Write-Host "Installing Windows ADK (this may take several minutes)..." -ForegroundColor Cyan
    
    $adkArgs = "/features OptionId.DeploymentTools"
    if ($Silent) {
        $adkArgs += " /quiet /norestart"
    }
    
    try {
        $process = Start-Process -FilePath $adkInstaller -ArgumentList $adkArgs -Wait -PassThru
        if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
            throw "ADK installation failed with exit code: $($process.ExitCode)"
        }
        Write-Host "ADK installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install ADK: $_"
        return $false
    }
    
    # Install WinPE add-on
    Write-Host "Installing WinPE add-on..." -ForegroundColor Cyan
    
    $winpeArgs = "/features OptionId.WindowsPreinstallationEnvironment"
    if ($Silent) {
        $winpeArgs += " /quiet /norestart"
    }
    
    try {
        $process = Start-Process -FilePath $winpeInstaller -ArgumentList $winpeArgs -Wait -PassThru
        if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
            throw "WinPE add-on installation failed with exit code: $($process.ExitCode)"
        }
        Write-Host "WinPE add-on installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install WinPE add-on: $_"
        return $false
    }
    
    return $true
}

function Get-ADKDownloadUrls {
    <#
    .SYNOPSIS
    Returns the download URLs for ADK and WinPE add-on
    #>
    
    return [PSCustomObject]@{
        ADK   = $script:ADKDownloadUrl
        WinPE = $script:WinPEAddonUrl
    }
}

Export-ModuleMember -Function Test-ADKInstalled, Get-ADKEnvironmentPath, Install-WindowsADK, Get-ADKDownloadUrls
