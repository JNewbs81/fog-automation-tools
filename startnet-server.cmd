wpeinit
@echo off
cls
color 0A

set "FOG_SERVER=192.168.1.211"
set "TOOLS_URL=http://%FOG_SERVER%/fog-automation-tools/bios-tools"

echo.
echo  =====================================================
echo   FOG BIOS Configuration Tool
echo  =====================================================
echo.
echo   Waiting for network to initialize...
echo.

REM Wait for network - try up to 30 seconds
set "ATTEMPTS=0"
:wait_network
set /a ATTEMPTS+=1
if %ATTEMPTS% gtr 10 (
    color 0C
    echo   ERROR: Cannot reach FOG server at %FOG_SERVER%
    echo   Check network connection and try again.
    echo.
    pause
    exit /b 1
)
ping -n 1 %FOG_SERVER% >nul 2>&1
if %errorlevel% neq 0 (
    echo   Attempt %ATTEMPTS%/10 - Waiting for network...
    ping -n 4 127.0.0.1 >nul
    goto :wait_network
)

echo   Connected to FOG server: %FOG_SERVER%
echo.
echo   Downloading tools from server...
echo.

REM Create directories
mkdir X:\bios-tools\dell 2>nul
mkdir X:\bios-tools\hp 2>nul
mkdir X:\bios-tools\lenovo 2>nul

REM Download all files using PowerShell (available in WinPE)
echo   Downloading auto-detect-apply.bat...
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/auto-detect-apply.bat' -OutFile 'X:\bios-tools\auto-detect-apply.bat' -UseBasicParsing" 2>nul

echo   Downloading Dell tools...
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/dell/apply-dell-bios.bat' -OutFile 'X:\bios-tools\dell\apply-dell-bios.bat' -UseBasicParsing" 2>nul
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/dell/fog-bios-config.cctk' -OutFile 'X:\bios-tools\dell\fog-bios-config.cctk' -UseBasicParsing" 2>nul
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/dell/cctk.exe' -OutFile 'X:\bios-tools\dell\cctk.exe' -UseBasicParsing" 2>nul

echo   Downloading HP tools...
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/hp/apply-hp-bios.bat' -OutFile 'X:\bios-tools\hp\apply-hp-bios.bat' -UseBasicParsing" 2>nul
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/hp/fog-config.REPSET' -OutFile 'X:\bios-tools\hp\fog-config.REPSET' -UseBasicParsing" 2>nul
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/hp/BiosConfigUtility64.exe' -OutFile 'X:\bios-tools\hp\BiosConfigUtility64.exe' -UseBasicParsing" 2>nul

echo   Downloading Lenovo tools...
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/lenovo/apply-lenovo-bios.bat' -OutFile 'X:\bios-tools\lenovo\apply-lenovo-bios.bat' -UseBasicParsing" 2>nul
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/lenovo/fog-config.ini' -OutFile 'X:\bios-tools\lenovo\fog-config.ini' -UseBasicParsing" 2>nul
powershell -Command "Invoke-WebRequest -Uri '%TOOLS_URL%/lenovo/ThinkBiosConfig.hta' -OutFile 'X:\bios-tools\lenovo\ThinkBiosConfig.hta' -UseBasicParsing" 2>nul

echo   Download complete.
echo.
echo  =====================================================
echo   Configuring BIOS for FOG imaging...
echo  =====================================================
echo.

X:\bios-tools\auto-detect-apply.bat

echo.
pause >nul
wpeutil reboot
