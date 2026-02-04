wpeinit
@echo off
cls
color 0A
echo.
echo  =====================================================
echo   FOG BIOS Configuration Tool - Automated Setup
echo  =====================================================
echo.
echo   This will automatically configure BIOS settings:
echo     - Disable Secure Boot
echo     - Enable UEFI Mode (disable Legacy/CSM)
echo     - Enable IPv4 PXE Boot
echo     - Set SATA to AHCI (Dell only)
echo     - Set Network as first boot device
echo.
echo   System will reboot to PXE after configuration.
echo.
echo  =====================================================
echo.
REM Use ping for delay (WinPE doesn't have timeout command)
ping -n 6 127.0.0.1 >nul

X:\bios-tools\auto-detect-apply.bat

echo.
echo  Configuration complete. If no reboot occurred,
echo  press any key to reboot manually...
pause >nul
wpeutil reboot
