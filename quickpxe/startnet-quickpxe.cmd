wpeinit
@echo off
setlocal EnableDelayedExpansion
cls
color 0A

echo.
echo  =====================================================
echo   QuickPXE - BIOS Configuration Tool
echo  =====================================================
echo.
echo   Initializing...
echo.

REM Wait for network to initialize
ping -n 5 127.0.0.1 >nul

REM ============================================
REM Detect System Manufacturer and Model
REM ============================================
echo   Detecting system information...

REM Get manufacturer
for /f "tokens=2 delims==" %%a in ('wmic computersystem get manufacturer /value 2^>nul ^| find "="') do set "RAW_MFG=%%a"

REM Normalize manufacturer name
set "MANUFACTURER="
echo !RAW_MFG! | findstr /i "Dell" >nul && set "MANUFACTURER=dell"
echo !RAW_MFG! | findstr /i "HP Hewlett" >nul && set "MANUFACTURER=hp"
echo !RAW_MFG! | findstr /i "Lenovo" >nul && set "MANUFACTURER=lenovo"

if "!MANUFACTURER!"=="" (
    echo   WARNING: Unknown manufacturer: !RAW_MFG!
    echo   Supported: Dell, HP, Lenovo
    pause
    goto :menu
)

REM Get model name
for /f "tokens=2 delims==" %%a in ('wmic computersystem get model /value 2^>nul ^| find "="') do set "RAW_MODEL=%%a"

REM Normalize model name for filename (lowercase, spaces to hyphens)
set "MODEL_FILE=!RAW_MODEL: =-!"
REM Convert to lowercase using a simple approach
for %%a in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do set "MODEL_FILE=!MODEL_FILE:%%a=%%a!"

echo.
echo   Manufacturer: !RAW_MFG!
echo   Model: !RAW_MODEL!
echo   Normalized: !MODEL_FILE!
echo.

REM ============================================
REM Find Configuration File
REM ============================================
echo   Searching for configuration file...

set "CONFIG_FILE="
set "CONFIG_TYPE="

REM Set file extension based on manufacturer
if "!MANUFACTURER!"=="dell" set "CONFIG_EXT=.cctk"
if "!MANUFACTURER!"=="hp" set "CONFIG_EXT=.REPSET"
if "!MANUFACTURER!"=="lenovo" set "CONFIG_EXT=.ini"

REM Check for model-specific config first
set "MODEL_CONFIG=X:\configs\!MANUFACTURER!\!MODEL_FILE!!CONFIG_EXT!"
if exist "!MODEL_CONFIG!" (
    set "CONFIG_FILE=!MODEL_CONFIG!"
    set "CONFIG_TYPE=Model-Specific"
    echo   Found model-specific config: !MODEL_CONFIG!
    goto :config_found
)

REM Try to match by model series (e.g., OptiPlex, EliteDesk, ThinkCentre)
REM Extract first word of model name as series
for /f "tokens=1" %%s in ("!RAW_MODEL!") do set "MODEL_SERIES=%%s"
set "SERIES_CONFIG=X:\configs\!MANUFACTURER!\!MODEL_SERIES!!CONFIG_EXT!"
if exist "!SERIES_CONFIG!" (
    set "CONFIG_FILE=!SERIES_CONFIG!"
    set "CONFIG_TYPE=Series"
    echo   Found series config: !SERIES_CONFIG!
    goto :config_found
)

REM Fall back to default config
set "DEFAULT_CONFIG=X:\configs\!MANUFACTURER!\default!CONFIG_EXT!"
if exist "!DEFAULT_CONFIG!" (
    set "CONFIG_FILE=!DEFAULT_CONFIG!"
    set "CONFIG_TYPE=Default"
    echo   Using default config: !DEFAULT_CONFIG!
    goto :config_found
)

REM No config found
echo.
echo   ERROR: No configuration file found for !MANUFACTURER! !RAW_MODEL!
echo.
echo   Expected locations:
echo     - X:\configs\!MANUFACTURER!\!MODEL_FILE!!CONFIG_EXT! (model-specific)
echo     - X:\configs\!MANUFACTURER!\!MODEL_SERIES!!CONFIG_EXT! (series)
echo     - X:\configs\!MANUFACTURER!\default!CONFIG_EXT! (default)
echo.
pause
goto :menu

:config_found
echo.
echo   Using !CONFIG_TYPE! configuration: !CONFIG_FILE!
echo.

REM ============================================
REM Apply BIOS Configuration
REM ============================================
echo  =====================================================
echo   Applying BIOS Configuration
echo  =====================================================
echo.

if "!MANUFACTURER!"=="dell" goto :apply_dell
if "!MANUFACTURER!"=="hp" goto :apply_hp
if "!MANUFACTURER!"=="lenovo" goto :apply_lenovo

:apply_dell
echo   Running Dell CCTK...
set "CCTK=X:\bios-tools\dell\cctk.exe"
if not exist "!CCTK!" (
    echo   ERROR: Dell CCTK not found at !CCTK!
    pause
    goto :menu
)

"!CCTK!" --infile="!CONFIG_FILE!"
set "APPLY_RESULT=!errorlevel!"

if !APPLY_RESULT! equ 0 (
    echo.
    echo   SUCCESS: BIOS configuration applied!
) else (
    echo.
    echo   NOTE: Some settings may not apply to this model (exit code: !APPLY_RESULT!)
)

REM Verify Secure Boot is disabled
echo.
echo   Verifying Secure Boot status...
for /f "tokens=*" %%a in ('"!CCTK!" --SecureBoot 2^>nul') do echo   %%a

REM Enable one-time PXE boot
echo.
echo   Setting one-time PXE boot...
"!CCTK!" --ForcePxeOnNextBoot=Enabled
goto :done

:apply_hp
echo   Running HP BCU...
set "BCU=X:\bios-tools\hp\BiosConfigUtility64.exe"
if not exist "!BCU!" set "BCU=X:\bios-tools\hp\BiosConfigUtility.exe"
if not exist "!BCU!" (
    echo   ERROR: HP BCU not found in X:\bios-tools\hp\
    pause
    goto :menu
)

"!BCU!" /set:"!CONFIG_FILE!"
set "APPLY_RESULT=!errorlevel!"

if !APPLY_RESULT! equ 0 (
    echo.
    echo   SUCCESS: BIOS configuration applied!
) else (
    echo.
    echo   NOTE: Some settings may not apply (exit code: !APPLY_RESULT!)
)
goto :done

:apply_lenovo
echo   Running Lenovo configuration...
set "TBCT=X:\bios-tools\lenovo\ThinkBiosConfig.hta"
if not exist "!TBCT!" (
    echo   ERROR: Lenovo ThinkBiosConfig not found at !TBCT!
    pause
    goto :menu
)

REM Lenovo uses WMI-based configuration
echo   Applying Lenovo BIOS settings...
mshta "!TBCT!" //B /infile:"!CONFIG_FILE!"
goto :done

:done
echo.
echo  =====================================================
echo   Configuration Complete
echo  =====================================================
echo.
echo   The system will reboot in 15 seconds.
echo   Press any key to reboot now, or Ctrl+C to cancel.
echo.
ping -n 16 127.0.0.1 >nul
wpeutil reboot
goto :eof

:menu
echo.
echo  =====================================================
echo   Manual Menu
echo  =====================================================
echo.
echo   1. Retry auto-detect
echo   2. Open command prompt
echo   3. Reboot
echo   4. Shutdown
echo.
set /p CHOICE="Select option: "

if "!CHOICE!"=="1" goto :start
if "!CHOICE!"=="2" cmd
if "!CHOICE!"=="3" wpeutil reboot
if "!CHOICE!"=="4" wpeutil shutdown
goto :menu

:start
cls
goto :eof
