@echo off
REM Auto-detect manufacturer and apply appropriate BIOS configuration
REM For use in WinPE or bootable USB
REM
REM Supported vendors: Dell, HP, Lenovo

setlocal enabledelayedexpansion

echo ============================================
echo FOG BIOS Auto-Configuration Tool
echo ============================================
echo.

REM Detect manufacturer using registry (WMIC not available in WinPE)
set "MANUFACTURER="
for /f "tokens=2*" %%a in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v SystemManufacturer 2^>nul ^| find "REG_SZ"') do (
    set "MANUFACTURER=%%b"
)

echo Detected Manufacturer: %MANUFACTURER%
echo.

REM Route to appropriate vendor script
echo %MANUFACTURER% | find /i "Dell" >nul
if %errorlevel% equ 0 (
    echo Detected DELL system - running Dell CCTK configuration...
    echo.
    if exist "%~dp0dell\apply-dell-bios.bat" (
        call "%~dp0dell\apply-dell-bios.bat"
    ) else (
        echo ERROR: Dell configuration script not found at %~dp0dell\apply-dell-bios.bat
        pause
        exit /b 1
    )
    goto :end
)

echo %MANUFACTURER% | find /i "HP" >nul
if %errorlevel% equ 0 goto :run_hp
echo %MANUFACTURER% | find /i "Hewlett" >nul
if %errorlevel% equ 0 goto :run_hp
goto :check_lenovo

:run_hp
echo Detected HP system - running HP BCU configuration...
echo.
if exist "%~dp0hp\apply-hp-bios.bat" (
    call "%~dp0hp\apply-hp-bios.bat"
) else (
    echo ERROR: HP configuration script not found at %~dp0hp\apply-hp-bios.bat
    pause
    exit /b 1
)
goto :end

:check_lenovo

echo %MANUFACTURER% | find /i "Lenovo" >nul
if %errorlevel% equ 0 (
    echo Detected LENOVO system - running Lenovo SRSETUP configuration...
    echo.
    if exist "%~dp0lenovo\apply-lenovo-bios.bat" (
        call "%~dp0lenovo\apply-lenovo-bios.bat"
    ) else (
        echo ERROR: Lenovo configuration script not found at %~dp0lenovo\apply-lenovo-bios.bat
        pause
        exit /b 1
    )
    goto :end
)

echo.
echo ============================================
echo UNSUPPORTED MANUFACTURER: %MANUFACTURER%
echo ============================================
echo.
echo This tool currently supports:
echo   - Dell (using Command Configure / CCTK)
echo   - HP (using BIOS Configuration Utility)
echo   - Lenovo (using Think BIOS Config Tool)
echo.
echo Please configure BIOS manually for this system.
pause
exit /b 1

:end
echo.
echo ============================================
echo BIOS configuration script completed
echo ============================================

