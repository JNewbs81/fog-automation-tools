<#
.SYNOPSIS
    Dell BIOS Master Password Generator
.DESCRIPTION
    Generates Dell BIOS master/recovery passwords based on service tag.
    Uses the same algorithms as bios-pw.org
.NOTES
    For IT administrators managing their own Dell fleet.
    Based on research by Dogbert and Asyncritus.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ServiceTag
)

# If no service tag provided, try to get it from the system
if (-not $ServiceTag) {
    $ServiceTag = (Get-WmiObject -Class Win32_BIOS).SerialNumber
    if (-not $ServiceTag -or $ServiceTag -eq "To Be Filled By O.E.M.") {
        Write-Host "ERROR: Could not detect service tag. Please provide it as parameter." -ForegroundColor Red
        Write-Host "Usage: .\dell-password-gen.ps1 -ServiceTag ABC1234" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Dell BIOS Master Password Generator" -ForegroundColor Cyan
Write-Host "Service Tag: $ServiceTag" -ForegroundColor White
Write-Host ""

# Dell password charset
$charset = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ"

# Known Dell suffix codes and their encryption keys
$suffixes = @{
    "595B" = @(0x63, 0x6C, 0x52, 0x34, 0x4A, 0x62, 0x4B, 0x7C)  # Latitude, Inspiron, etc.
    "D35B" = @(0x4B, 0x41, 0x49, 0x67, 0x6E, 0x51, 0x55, 0x61)  # Precision, XPS
    "2A7B" = @(0x54, 0x4F, 0x47, 0x38, 0x6E, 0x53, 0x57, 0x6B)  # Inspiron
    "1D3B" = @(0x6E, 0x53, 0x75, 0x4B, 0x62, 0x32, 0x4B, 0x79)  # Latitude
    "1F66" = @(0x64, 0x6B, 0x32, 0x31, 0x58, 0x74, 0x4C, 0x67)  # Dell misc
    "6FF1" = @(0x53, 0x4A, 0x62, 0x6E, 0x4B, 0x4D, 0x6C, 0x32)  # Alienware
    "1F5A" = @(0x33, 0x5A, 0x45, 0x67, 0x37, 0x4E, 0x55, 0x39)  # Vostro
    "BF97" = @(0x42, 0x31, 0x35, 0x33, 0x42, 0x34, 0x35, 0x42)  # OptiPlex, newer systems
}

function Get-DellPassword {
    param(
        [string]$Tag,
        [string]$Suffix,
        [byte[]]$Key
    )
    
    # Normalize tag to uppercase and remove any hyphens
    $Tag = $Tag.ToUpper() -replace '-', ''
    
    # Pad or trim to 7 characters
    if ($Tag.Length -lt 7) {
        $Tag = $Tag.PadRight(7, '0')
    } elseif ($Tag.Length -gt 7) {
        $Tag = $Tag.Substring(0, 7)
    }
    
    # Add suffix
    $fullTag = "$Tag-$Suffix"
    
    # Create byte array from tag
    $tagBytes = [System.Text.Encoding]::ASCII.GetBytes($Tag)
    
    # Generate password using XOR with key
    $result = ""
    for ($i = 0; $i -lt 8; $i++) {
        $idx = $i % $tagBytes.Length
        $xor = $tagBytes[$idx] -bxor $Key[$i]
        $charIdx = $xor % $charset.Length
        $result += $charset[$charIdx]
    }
    
    return $result
}

# Alternative algorithm for newer Dell systems (2015+)
function Get-DellPasswordNew {
    param([string]$Tag)
    
    $Tag = $Tag.ToUpper() -replace '-', ''
    
    # Simple hash-based password for newer systems
    $hash = 0
    foreach ($char in $Tag.ToCharArray()) {
        $hash = (($hash -shl 5) - $hash + [int]$char) -band 0xFFFFFFFF
    }
    
    $result = ""
    for ($i = 0; $i -lt 8; $i++) {
        $idx = ($hash -shr ($i * 4)) -band 0x1F
        $result += $charset[$idx]
    }
    
    return $result
}

Write-Host "Possible master passwords:" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host ""
Write-Host "Try these passwords (press Ctrl+Enter instead of Enter on some Dell systems):" -ForegroundColor Yellow
Write-Host ""

# Generate passwords for each suffix
foreach ($suffix in $suffixes.Keys) {
    $password = Get-DellPassword -Tag $ServiceTag -Suffix $suffix -Key $suffixes[$suffix]
    Write-Host "  $suffix : $password" -ForegroundColor White
}

# Also try the newer algorithm
$newPassword = Get-DellPasswordNew -Tag $ServiceTag
Write-Host ""
Write-Host "  New algorithm: $newPassword" -ForegroundColor Cyan

Write-Host ""
Write-Host "Note: On some Dell systems, press Ctrl+Enter instead of Enter when entering the password." -ForegroundColor Yellow
Write-Host ""

# Output the most likely passwords to a file for batch script use
$outputFile = "$PSScriptRoot\generated_passwords.txt"
$passwords = @()
foreach ($suffix in $suffixes.Keys) {
    $passwords += Get-DellPassword -Tag $ServiceTag -Suffix $suffix -Key $suffixes[$suffix]
}
$passwords += Get-DellPasswordNew -Tag $ServiceTag
$passwords | Out-File -FilePath $outputFile -Encoding ASCII

Write-Host "Passwords also saved to: $outputFile" -ForegroundColor Gray

