@echo off
REM Lenovo BIOS Configuration Script for FOG Imaging
REM Requires Lenovo Think BIOS Config Tool (SRSETUP or WMI method)
REM Download from: https://support.lenovo.com/solutions/ht100612
REM
REM Settings applied:
REM   - Secure Boot: Disabled
REM   - IPv4 PXE Boot: Enabled
REM   - Boot Order: NIC first

setlocal enabledelayedexpansion

echo ============================================
echo Lenovo BIOS Configuration for FOG Imaging
echo ============================================
echo.

REM Check for Think BIOS Config Tool in common locations
set "TBCT="
if exist "%~dp0SRSETUPWIN64.exe" set "TBCT=%~dp0SRSETUPWIN64.exe"
if exist "%~dp0SRSETUP64.exe" set "TBCT=%~dp0SRSETUP64.exe"
if exist "%~dp0WinSRSetup64.exe" set "TBCT=%~dp0WinSRSetup64.exe"
if exist "C:\Program Files (x86)\Lenovo\BIOS Config Tool\SRSETUPWIN64.exe" set "TBCT=C:\Program Files (x86)\Lenovo\BIOS Config Tool\SRSETUPWIN64.exe"
if exist "X:\Lenovo\SRSETUPWIN64.exe" set "TBCT=X:\Lenovo\SRSETUPWIN64.exe"

if "%TBCT%"=="" (
    echo ERROR: Lenovo Think BIOS Config Tool not found!
    echo Please ensure SRSETUP is placed in the same directory as this script.
    echo Download from: https://support.lenovo.com/solutions/ht100612
    pause
    exit /b 1
)

echo Using Think BIOS Config Tool: %TBCT%
echo.

REM Check for BIOS password
set "PWD_ARG="
if exist "%~dp0bios_password.txt" (
    set /p BIOS_PWD=<"%~dp0bios_password.txt"
    set "PWD_ARG=,pass:!BIOS_PWD!"
    echo BIOS password file found.
)

REM Check if INI config file exists (preferred method)
if exist "%~dp0fog-config.ini" (
    echo Using INI configuration file...
    "%TBCT%" /config:"%~dp0fog-config.ini"
    if %errorlevel% neq 0 (
        echo WARNING: INI application had issues. Trying individual settings...
    ) else (
        echo SUCCESS: INI configuration applied
        goto :verify
    )
)

echo Applying individual BIOS settings...
echo.

echo Step 1: Disabling Secure Boot...
"%TBCT%" /set:SecureBoot,Disabled%PWD_ARG%
if %errorlevel% neq 0 (
    REM Try alternative setting names
    "%TBCT%" /set:"Secure Boot",Disabled%PWD_ARG%
    if %errorlevel% neq 0 (
        echo WARNING: Failed to disable Secure Boot
    ) else (
        echo SUCCESS: Secure Boot disabled
    )
) else (
    echo SUCCESS: Secure Boot disabled
)
echo.

echo Step 2: Enabling Ethernet LAN Boot Option...
"%TBCT%" /set:EthernetLANOptionROM,Enabled%PWD_ARG%
if %errorlevel% neq 0 (
    "%TBCT%" /set:"Ethernet LAN Option ROM",Enabled%PWD_ARG%
    if %errorlevel% neq 0 (
        echo WARNING: Failed to enable Ethernet LAN Option ROM
    ) else (
        echo SUCCESS: Ethernet LAN Option ROM enabled
    )
) else (
    echo SUCCESS: Ethernet LAN Option ROM enabled
)
echo.

echo Step 3: Enabling IPv4 PXE Boot...
"%TBCT%" /set:IPv4PXEBoot,Enabled%PWD_ARG%
if %errorlevel% neq 0 (
    "%TBCT%" /set:"IPv4 PXE Boot",Enabled%PWD_ARG%
    if %errorlevel% neq 0 (
        "%TBCT%" /set:NetworkBoot,Enabled%PWD_ARG%
        if %errorlevel% neq 0 (
            echo WARNING: Failed to enable IPv4 PXE Boot
        ) else (
            echo SUCCESS: Network Boot enabled
        )
    ) else (
        echo SUCCESS: IPv4 PXE Boot enabled
    )
) else (
    echo SUCCESS: IPv4 PXE Boot enabled
)
echo.

echo Step 4: Enabling UEFI/Legacy Boot (for PXE compatibility)...
"%TBCT%" /set:BootMode,"UEFI Only"%PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Failed to set boot mode
) else (
    echo SUCCESS: Boot mode set to UEFI Only
)
echo.

echo Step 5: Setting Boot Priority...
REM Enable Network Boot in boot priority
"%TBCT%" /set:NetworkBoot,Enabled%PWD_ARG%
echo Network Boot enabled for boot sequence
echo.

echo Step 6: Enabling Wake on LAN...
"%TBCT%" /set:WakeOnLAN,Enabled%PWD_ARG%
if %errorlevel% neq 0 (
    "%TBCT%" /set:"Wake on LAN",Enabled%PWD_ARG%
    if %errorlevel% neq 0 (
        echo WARNING: Failed to enable Wake on LAN
    ) else (
        echo SUCCESS: Wake on LAN enabled
    )
) else (
    echo SUCCESS: Wake on LAN enabled
)
echo.

echo Step 7: Setting Wake on LAN from S4/S5...
"%TBCT%" /set:WakeOnLANfromDock,Enabled%PWD_ARG%
"%TBCT%" /set:"Wake on LAN from S4/S5",ACOnly%PWD_ARG%
echo.

:verify
echo ============================================
echo Verifying Current Settings
echo ============================================
echo.

REM Export current config for verification
set "EXPORTCONFIG=%TEMP%\lenovo_current_config.ini"
"%TBCT%" /export:"%EXPORTCONFIG%"
if exist "%EXPORTCONFIG%" (
    echo Checking Secure Boot status...
    findstr /i "SecureBoot\|Secure Boot" "%EXPORTCONFIG%"
    echo.
    
    echo Checking Network Boot status...
    findstr /i "Ethernet\|Network\|PXE\|IPv4" "%EXPORTCONFIG%"
    echo.
    
    echo Full configuration exported to: %EXPORTCONFIG%
) else (
    echo Could not export current configuration for verification.
)

echo.
echo ============================================
echo Configuration Complete!
echo ============================================
echo.
echo The system will reboot in 10 seconds to apply changes...
echo Press Ctrl+C to cancel reboot.
echo.

timeout /t 10
shutdown /r /t 0 /f

