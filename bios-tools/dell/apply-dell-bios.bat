@echo off
REM Dell BIOS Configuration Script for FOG Imaging
REM Uses Dell Command Configure export file for reliable multi-platform support

setlocal enabledelayedexpansion

echo ============================================
echo Dell BIOS Configuration for FOG Imaging
echo ============================================
echo.

REM Find CCTK
set "CCTK="
if exist "%~dp0cctk.exe" set "CCTK=%~dp0cctk.exe"
if "%CCTK%"=="" if exist "X:\bios-tools\dell\cctk.exe" set "CCTK=X:\bios-tools\dell\cctk.exe"

if "%CCTK%"=="" (
    echo ERROR: cctk.exe not found!
    pause
    exit /b 1
)

echo Using CCTK: %CCTK%
echo.

REM Find config file
set "CONFIG="
if exist "%~dp0fog-bios-config.cctk" set "CONFIG=%~dp0fog-bios-config.cctk"
if "%CONFIG%"=="" if exist "X:\bios-tools\dell\fog-bios-config.cctk" set "CONFIG=X:\bios-tools\dell\fog-bios-config.cctk"

if "%CONFIG%"=="" (
    echo ERROR: fog-bios-config.cctk not found!
    echo Expected at: %~dp0fog-bios-config.cctk
    pause
    exit /b 1
)

echo Using config: %CONFIG%
echo.

REM ============================================
REM Apply BIOS Configuration from File
REM ============================================
echo Applying BIOS settings from config file...
echo.

"%CCTK%" --infile="%CONFIG%"
set APPLY_RESULT=%errorlevel%

if %APPLY_RESULT% equ 0 (
    echo.
    echo SUCCESS: All settings applied!
) else (
    echo.
    echo NOTE: Some settings may not apply to this model (exit code: %APPLY_RESULT%)
    echo This is normal - CCTK skips unsupported settings gracefully.
)
echo.

REM ============================================
REM Ensure Critical Settings (fallback)
REM ============================================
echo Verifying critical settings...
echo.

REM Set Active Boot List to UEFI (critical for FOG)
echo Setting Active Boot List to UEFI...
"%CCTK%" bootorder --ActiveBootList=uefi
if %errorlevel% equ 0 (echo   SUCCESS) else (echo   Already set or not needed)
echo.

REM Force PXE on Next Boot (ensures we boot to FOG)
echo Enabling Force PXE on Next Boot...
"%CCTK%" --ForcePxeOnNextBoot=Enabled
if %errorlevel% equ 0 (echo   SUCCESS) else (echo   Already set or not supported)
echo.

REM ============================================
REM Display Final Settings
REM ============================================
echo ============================================
echo Configuration Complete - Verifying...
echo ============================================
echo.
echo Active Boot List:
"%CCTK%" bootorder --ActiveBootList
echo.
echo Legacy Settings:
"%CCTK%" --LegacyOrom
"%CCTK%" --AttemptLegacyBoot
echo.
echo Security:
"%CCTK%" --SecureBoot
echo.
echo Network:
"%CCTK%" --UefiNwStack
"%CCTK%" --EmbNic1
echo.
echo PXE Boot:
"%CCTK%" --ForcePxeOnNextBoot
echo.
echo Boot Order:
"%CCTK%" bootorder
echo.

echo ============================================
echo Rebooting to PXE in 10 seconds...
echo Press Ctrl+C to cancel
echo ============================================
ping -n 11 127.0.0.1 >nul

wpeutil reboot
