@echo off
REM HP BIOS Configuration Script for FOG Imaging
REM Requires HP BIOS Configuration Utility (BCU)
REM Download from: https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html
REM
REM Settings applied:
REM   - Secure Boot: Disabled
REM   - IPv4 PXE Boot: Enabled
REM   - Boot Order: NIC first

setlocal enabledelayedexpansion

echo ============================================
echo HP BIOS Configuration for FOG Imaging
echo ============================================
echo.

REM Check for BCU 64-bit in common locations (64-bit only)
set "BCU="
if exist "%~dp0BiosConfigUtility64.exe" set "BCU=%~dp0BiosConfigUtility64.exe"
if "%BCU%"=="" if exist "C:\Program Files\HP\BIOS Configuration Utility\BiosConfigUtility64.exe" set "BCU=C:\Program Files\HP\BIOS Configuration Utility\BiosConfigUtility64.exe"
if "%BCU%"=="" if exist "C:\Program Files (x86)\HP\BIOS Configuration Utility\BiosConfigUtility64.exe" set "BCU=C:\Program Files (x86)\HP\BIOS Configuration Utility\BiosConfigUtility64.exe"
if "%BCU%"=="" if exist "X:\HP\BiosConfigUtility64.exe" set "BCU=X:\HP\BiosConfigUtility64.exe"

if "%BCU%"=="" (
    echo ERROR: HP BIOS Configuration Utility not found!
    echo Please ensure BCU is installed or placed in the same directory as this script.
    echo Download from: https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html
    pause
    exit /b 1
)

echo Using BCU: %BCU%
echo.

REM Check for BIOS password
set "PWD_ARG="
if exist "%~dp0bios_password.txt" (
    set /p BIOS_PWD=<"%~dp0bios_password.txt"
    set "PWD_ARG=/cpwdfile:"%~dp0bios_password.bin""
    echo BIOS password file found.
    
    REM If bin file doesn't exist, we need to create it or use plaintext
    if not exist "%~dp0bios_password.bin" (
        set "PWD_ARG=/cpwd:!BIOS_PWD!"
    )
)

REM Check if REPSET file exists (preferred method)
if exist "%~dp0fog-config.REPSET" (
    echo Using REPSET configuration file...
    "%BCU%" /setconfig:"%~dp0fog-config.REPSET" %PWD_ARG%
    if %errorlevel% neq 0 (
        echo WARNING: REPSET application had issues. Trying individual settings...
    ) else (
        echo SUCCESS: REPSET configuration applied
        goto :verify
    )
)

echo Applying individual BIOS settings...
echo.

REM Create temporary config file for settings
set "TEMPCONFIG=%TEMP%\hp_fog_config.txt"

echo. > "%TEMPCONFIG%"
echo BIOSConfig 1.0 >> "%TEMPCONFIG%"
echo ; >> "%TEMPCONFIG%"
echo ; HP BIOS Configuration for FOG Imaging >> "%TEMPCONFIG%"
echo ; >> "%TEMPCONFIG%"

REM Secure Boot Configuration - Disable Secure Boot, UEFI mode only (no Legacy)
echo. >> "%TEMPCONFIG%"
echo Secure Boot Configuration >> "%TEMPCONFIG%"
echo 	Configure Legacy Support and Secure Boot >> "%TEMPCONFIG%"
echo 		*Legacy Support Disable and Secure Boot Disable >> "%TEMPCONFIG%"
echo. >> "%TEMPCONFIG%"

REM Alternative Secure Boot setting format for newer systems
echo SecureBoot >> "%TEMPCONFIG%"
echo 	*Disable >> "%TEMPCONFIG%"
echo. >> "%TEMPCONFIG%"

REM Boot Mode - UEFI Native only, disable CSM/Legacy
echo Boot Mode >> "%TEMPCONFIG%"
echo 	*UEFI Native (Without CSM) >> "%TEMPCONFIG%"
echo. >> "%TEMPCONFIG%"

echo Legacy Boot Options >> "%TEMPCONFIG%"
echo 	*Disable >> "%TEMPCONFIG%"
echo. >> "%TEMPCONFIG%"

echo CSM Support >> "%TEMPCONFIG%"
echo 	*Disable >> "%TEMPCONFIG%"
echo. >> "%TEMPCONFIG%"

REM Network Boot
echo. >> "%TEMPCONFIG%"
echo Network (PXE) Boot >> "%TEMPCONFIG%"
echo 	*Enable >> "%TEMPCONFIG%"
echo. >> "%TEMPCONFIG%"

REM IPv4 Network Boot
echo Network Boot >> "%TEMPCONFIG%"
echo 	*Enable >> "%TEMPCONFIG%"
echo. >> "%TEMPCONFIG%"

REM UEFI Boot Order - Put Network first
echo UEFI Boot Order >> "%TEMPCONFIG%"
echo 	Network Boot >> "%TEMPCONFIG%"
echo 	OS Boot Manager >> "%TEMPCONFIG%"
echo 	USB Hard Drive >> "%TEMPCONFIG%"
echo. >> "%TEMPCONFIG%"

echo Step 1: Applying configuration...
"%BCU%" /setconfig:"%TEMPCONFIG%" %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Some settings may not have applied. Check output above.
) else (
    echo SUCCESS: Configuration applied
)
echo.

:verify
echo ============================================
echo Verifying Current Settings
echo ============================================
echo.

REM Export current config for verification
set "EXPORTCONFIG=%TEMP%\hp_current_config.txt"
"%BCU%" /getconfig:"%EXPORTCONFIG%"

echo Checking Secure Boot status...
findstr /i "Secure Boot" "%EXPORTCONFIG%"
echo.

echo Checking Network Boot status...
findstr /i "Network.*Boot\|PXE" "%EXPORTCONFIG%"
echo.

echo ============================================
echo Configuration Complete!
echo ============================================
echo.
echo Full configuration exported to: %EXPORTCONFIG%
echo.
echo The system will reboot in 10 seconds to apply changes...
echo Press Ctrl+C to cancel reboot.
echo.

timeout /t 10
shutdown /r /t 0 /f

