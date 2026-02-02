@echo off
REM Dell BIOS Configuration Script for FOG Imaging
REM Requires Dell Command Configure (CCTK) to be present
REM Download from: https://www.dell.com/support/kbdoc/en-us/000178000/dell-command-configure
REM
REM Settings applied:
REM   - Secure Boot: Disabled
REM   - Boot List Type: UEFI (not Legacy)
REM   - Legacy Option ROM: Disabled
REM   - UEFI Network Stack: Enabled
REM   - Embedded NIC: Enabled with IPv4 PXE
REM   - SATA Operation: AHCI (not RAID)
REM   - Warnings and Errors: Continue (no prompts)
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
set "PWD_ARG="

if exist "%~dp0bios_password.txt" (
    set /p BIOS_PWD=<"%~dp0bios_password.txt"
    echo BIOS password file found.
    set "PWD_ARG=--valsetuppwd=!BIOS_PWD!"
    goto :skip_password_gen
)

REM Try to detect if password is needed by running a simple query
echo Checking if BIOS password is set...
"%CCTK%" --SecureBoot >nul 2>&1
if %errorlevel% equ 0 goto :skip_password_gen

echo.
echo BIOS appears to be password protected. Attempting auto-recovery...
echo.

REM Get service tag
for /f "tokens=2 delims==" %%a in ('wmic bios get serialnumber /value 2^>nul ^| find "="') do set "SERVICE_TAG=%%a"
set "SERVICE_TAG=%SERVICE_TAG: =%"

if "%SERVICE_TAG%"=="" (
    echo WARNING: Could not detect service tag for password recovery.
    goto :skip_password_gen
)

echo Service Tag: %SERVICE_TAG%
echo Generating potential master passwords...

REM Generate Dell master passwords using PowerShell
if exist "%~dp0dell-password-gen.ps1" (
    powershell -ExecutionPolicy Bypass -File "%~dp0dell-password-gen.ps1" -ServiceTag "%SERVICE_TAG%" >nul 2>&1
)

REM Try each generated password
if exist "%~dp0generated_passwords.txt" (
    echo Testing generated passwords...
    for /f "usebackq tokens=*" %%p in ("%~dp0generated_passwords.txt") do (
        echo   Trying password: %%p
        "%CCTK%" --SecureBoot --valsetuppwd=%%p >nul 2>&1
        if !errorlevel! equ 0 (
            echo   SUCCESS: Password %%p works!
            set "BIOS_PWD=%%p"
            set "PWD_ARG=--valsetuppwd=%%p"
            goto :skip_password_gen
        )
    )
    echo   No auto-generated password worked.
    echo   You may need to manually clear the BIOS password.
)

:skip_password_gen
echo.

echo Step 1: Disabling Secure Boot...
"%CCTK%" --SecureBoot=Disabled %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Failed to disable Secure Boot ^(may already be disabled or not supported^)
) else (
    echo SUCCESS: Secure Boot disabled
)
echo.

echo Step 2: Setting Boot List Type to UEFI...
"%CCTK%" bootorder --BootListType=uefi %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Failed to set Boot List Type to UEFI
) else (
    echo SUCCESS: Boot List Type set to UEFI
)
echo.

echo Step 3: Disabling Legacy Option ROM...
"%CCTK%" --LegacyOrom=Disabled %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Failed to disable Legacy Option ROM ^(may not be supported on this model^)
) else (
    echo SUCCESS: Legacy Option ROM disabled
)
echo.

echo Step 4: Enabling UEFI Network Stack...
"%CCTK%" --UefiNwStack=Enabled %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: UEFI Network Stack setting not available on this model
) else (
    echo SUCCESS: UEFI Network Stack enabled
)
echo.

echo Step 5: Enabling Embedded NIC...
"%CCTK%" --EmbNic1=Enabled %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Failed to enable Embedded NIC
) else (
    echo SUCCESS: Embedded NIC enabled
)
echo.

echo Step 6: Enabling IPv4 PXE Boot on NIC...
"%CCTK%" --EmbNic1Ipv4=Enabled %PWD_ARG%
if %errorlevel% neq 0 (
    REM Try alternative parameter names for different Dell models
    "%CCTK%" --Nic1Ipv4PxeBoot=Enabled %PWD_ARG%
    if %errorlevel% neq 0 (
        echo WARNING: Could not enable IPv4 PXE Boot ^(may not be supported or already enabled^)
    ) else (
        echo SUCCESS: IPv4 PXE Boot enabled ^(alternate parameter^)
    )
) else (
    echo SUCCESS: IPv4 PXE Boot enabled
)
echo.

echo Step 7: Setting SATA Operation to AHCI...
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

echo Step 8: Disabling Warnings and Errors prompts...
"%CCTK%" --WarningsAndErr=ContWrnErr %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Warnings and Errors setting not available on this model
) else (
    echo SUCCESS: Warnings and Errors set to Continue
)
echo.

echo Step 9: Setting Boot Order ^(NIC First^)...
REM Get current boot order to understand available devices
echo Current boot order:
"%CCTK%" bootorder
echo.

REM Enable NIC in boot list and set sequence
"%CCTK%" bootorder --EnableDevice=EmbNic1 %PWD_ARG%
if %errorlevel% neq 0 (
    echo WARNING: Could not enable NIC in boot order
) else (
    echo SUCCESS: NIC enabled in boot order
)

REM Try to set NIC as first boot device
"%CCTK%" bootorder --Sequence=EmbNic1 %PWD_ARG%
if %errorlevel% neq 0 (
    REM Try with full boot sequence including common device names
    "%CCTK%" bootorder --Sequence=EmbNic1,hdd %PWD_ARG%
    if %errorlevel% neq 0 (
        echo WARNING: Could not modify boot sequence automatically
        echo You may need to set boot order manually in BIOS
    ) else (
        echo SUCCESS: Boot sequence set ^(NIC, HDD^)
    )
) else (
    echo SUCCESS: NIC set as first boot device
)
echo.

echo ============================================
echo Configuration Complete!
echo ============================================
echo.
echo Current BIOS Settings:
"%CCTK%" --SecureBoot
"%CCTK%" --UefiNwStack
"%CCTK%" --EmbNic1
"%CCTK%" --WarningsAndErr
"%CCTK%" --EmbSataRaid 2>nul || "%CCTK%" --SataOperation 2>nul
echo.
echo Boot Order:
"%CCTK%" bootorder
echo.
echo The system will reboot in 10 seconds to apply changes...
echo Press Ctrl+C to cancel reboot.
echo.

timeout /t 10
shutdown /r /t 0 /f
