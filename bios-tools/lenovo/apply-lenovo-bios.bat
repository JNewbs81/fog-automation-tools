@echo off
REM Lenovo BIOS Configuration Script for FOG Imaging
REM Uses Think BIOS Config Tool (ThinkBiosConfig.hta)
REM Download from: https://download.lenovo.com/cdrt/tools/tbct144.zip
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
if exist "%~dp0ThinkBiosConfig.hta" set "TBCT=%~dp0ThinkBiosConfig.hta"
if exist "%~dp0tbct144\ThinkBiosConfig.hta" set "TBCT=%~dp0tbct144\ThinkBiosConfig.hta"
if exist "X:\Lenovo\ThinkBiosConfig.hta" set "TBCT=X:\Lenovo\ThinkBiosConfig.hta"

if "%TBCT%"=="" (
    echo ERROR: Think BIOS Config Tool not found!
    echo Please ensure ThinkBiosConfig.hta is in the same directory as this script.
    echo Download from: https://download.lenovo.com/cdrt/tools/tbct144.zip
    pause
    exit /b 1
)

echo Using Think BIOS Config Tool: %TBCT%
echo.

REM Check for config INI file
set "CONFIG_INI=%~dp0fog-config.ini"
if not exist "%CONFIG_INI%" (
    echo ERROR: Configuration file not found: %CONFIG_INI%
    pause
    exit /b 1
)

echo Using configuration: %CONFIG_INI%
echo.

REM Check for BIOS password file
set "PWD_ARG="
if exist "%~dp0bios_password.txt" (
    set /p BIOS_PWD=<"%~dp0bios_password.txt"
    set "PWD_ARG=pass:!BIOS_PWD!"
    echo BIOS password file found.
    echo.
)

echo ============================================
echo Applying BIOS Configuration
echo ============================================
echo.
echo This will apply the following settings:
echo   - Secure Boot: Disabled
echo   - Network Boot: Enabled  
echo   - IPv4 PXE Boot: Enabled
echo   - Wake on LAN: Enabled
echo.

REM Apply configuration using Think BIOS Config Tool
REM The HTA accepts: "file:<inipath>" and optionally "pass:<password>"
if defined PWD_ARG (
    echo Running: mshta "%TBCT%" "file:%CONFIG_INI%" "%PWD_ARG%"
    mshta "%TBCT%" "file:%CONFIG_INI%" "%PWD_ARG%"
) else (
    echo Running: mshta "%TBCT%" "file:%CONFIG_INI%"
    mshta "%TBCT%" "file:%CONFIG_INI%"
)

set "RESULT=%errorlevel%"

echo.
if %RESULT% equ 0 (
    echo SUCCESS: BIOS configuration applied
) else if %RESULT% equ 1 (
    echo WARNING: Some settings may not have applied ^(return code: %RESULT%^)
) else if %RESULT% equ 3 (
    echo ERROR: Password mismatch ^(return code: %RESULT%^)
) else (
    echo Result code: %RESULT%
)

echo.
echo ============================================
echo Configuration Complete!
echo ============================================
echo.
echo NOTE: Some BIOS changes require a reboot to take effect.
echo.
echo The system will reboot in 10 seconds to apply changes...
echo Press Ctrl+C to cancel reboot.
echo.

timeout /t 10
shutdown /r /t 0 /f
