@echo off
REM Dell BIOS Configuration Script for FOG Imaging
REM Requires Dell Command Configure (CCTK) to be present
REM Download from: https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure
REM
REM Settings applied:
REM   - Secure Boot: Disabled
REM   - IPv4 PXE Boot: Enabled
REM   - SATA Operation: AHCI (not RAID)
REM   - Boot Order: NIC first

setlocal enabledelayedexpansion

echo ============================================
echo Dell BIOS Configuration for FOG Imaging
echo ============================================
echo.

REM Check for CCTK in common locations
set "CCTK="
if exist "%~dp0cctk.exe" set "CCTK=%~dp0cctk.exe"
if exist "C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe" set "CCTK=C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe"
if exist "C:\Program Files\Dell\Command Configure\X86_64\cctk.exe" set "CCTK=C:\Program Files\Dell\Command Configure\X86_64\cctk.exe"
if exist "X:\Dell\cctk.exe" set "CCTK=X:\Dell\cctk.exe"

if "%CCTK%"=="" (
    echo ERROR: Dell Command Configure ^(cctk.exe^) not found!
    echo Please ensure CCTK is installed or placed in the same directory as this script.
    pause
    exit /b 1
)

echo Using CCTK: %CCTK%
echo.

REM Check if BIOS password is required
set "BIOS_PWD="
if exist "%~dp0bios_password.txt" (
    set /p BIOS_PWD=<"%~dp0bios_password.txt"
    echo BIOS password file found.
)

if defined BIOS_PWD (
    set "PWD_ARG=--valsetuppwd=!BIOS_PWD!"
) else (
    set "PWD_ARG="
)

echo Step 1: Disabling Secure Boot...
"%CCTK%" --SecureBoot=Disabled %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Failed to disable Secure Boot ^(may already be disabled or not supported^)
) else (
    echo SUCCESS: Secure Boot disabled
)
echo.

echo Step 2: Enabling Embedded NIC...
"%CCTK%" --EmbNic1=Enabled %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Failed to enable Embedded NIC
) else (
    echo SUCCESS: Embedded NIC enabled
)
echo.

echo Step 3: Enabling IPv4 PXE Boot on NIC...
"%CCTK%" --EmbNic1Ipv4=Enabled %PWD_ARG%
if %errorlevel% neq 0 (
    REM Try alternative parameter names for different Dell models
    "%CCTK%" --EmbNic1BootProto=PXE %PWD_ARG%
    if %errorlevel% neq 0 (
        "%CCTK%" --LegacyOrom=Enabled %PWD_ARG%
        echo WARNING: Used fallback PXE settings
    ) else (
        echo SUCCESS: NIC Boot Protocol set to PXE
    )
) else (
    echo SUCCESS: IPv4 PXE Boot enabled
)
echo.

echo Step 4: Setting SATA Operation to AHCI...
"%CCTK%" --EmbSataRaid=Ahci %PWD_ARG%
if %errorlevel% neq 0 (
    REM Try alternative parameter for different models
    "%CCTK%" --SataOperation=Ahci %PWD_ARG%
    if %errorlevel% neq 0 (
        echo WARNING: Failed to set SATA to AHCI ^(may already be set or not supported^)
    ) else (
        echo SUCCESS: SATA Operation set to AHCI
    )
) else (
    echo SUCCESS: SATA set to AHCI
)
echo.

echo Step 4b: Setting Boot Mode to UEFI ^(not Legacy^)...
"%CCTK%" --BootMode=Uefi %PWD_ARG%
if %errorlevel% neq 0 (
    REM Try alternative parameter names
    "%CCTK%" --LegacyOrom=Disabled %PWD_ARG%
    "%CCTK%" --BootList=Uefi %PWD_ARG%
    echo Note: Boot mode settings applied ^(may require reboot^)
) else (
    echo SUCCESS: Boot Mode set to UEFI
)
echo.

echo Step 5: Setting Boot Order ^(NIC First^)...
REM Get current boot order to understand available devices
"%CCTK%" --BootOrder
echo.

REM Try to set NIC as first boot device
"%CCTK%" --BootOrder=EmbNic1 %PWD_ARG%
if %errorlevel% neq 0 (
    REM Try with full boot sequence
    "%CCTK%" --BootOrder=EmbNic1,hdd,usbdev %PWD_ARG%
    if %errorlevel% neq 0 (
        echo WARNING: Could not modify boot order automatically
        echo You may need to set boot order manually or use --bootorder with correct device names
    ) else (
        echo SUCCESS: Boot order set ^(NIC, HDD, USB^)
    )
) else (
    echo SUCCESS: NIC set as first boot device
)
echo.

echo Step 6: Enabling UEFI Network Stack...
"%CCTK%" --UefiNwStack=Enabled %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: UEFI Network Stack setting not available on this model
) else (
    echo SUCCESS: UEFI Network Stack enabled
)
echo.

echo ============================================
echo Configuration Complete!
echo ============================================
echo.
echo Current BIOS Settings:
"%CCTK%" --SecureBoot
"%CCTK%" --EmbNic1
"%CCTK%" --EmbSataRaid 2>nul || "%CCTK%" --SataOperation 2>nul
echo.
echo The system will reboot in 10 seconds to apply changes...
echo Press Ctrl+C to cancel reboot.
echo.

timeout /t 10
shutdown /r /t 0 /f

