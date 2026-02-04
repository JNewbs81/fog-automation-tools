@echo off
REM ============================================
REM STASHED PASSWORD RECOVERY CODE
REM Add this back to apply-dell-bios.bat when ready
REM ============================================

REM Place this code after the CCTK check, before Step 1

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

REM Get service tag using WMIC (works with WinPE-WMI package)
for /f "skip=1 tokens=*" %%a in ('wmic bios get serialnumber 2^>nul') do (
    if not "%%a"=="" set "SERVICE_TAG=%%a"
)
REM Trim trailing spaces
for /f "tokens=* delims= " %%a in ("%SERVICE_TAG%") do set "SERVICE_TAG=%%a"

if "%SERVICE_TAG%"=="" (
    echo WARNING: Could not detect service tag for password recovery.
    goto :skip_password_gen
)

echo Service Tag: %SERVICE_TAG%
echo Generating potential master passwords...

REM Generate Dell master passwords using VBScript (works in WinPE)
if exist "%~dp0dell-password-gen.vbs" (
    cscript //nologo "%~dp0dell-password-gen.vbs" "%SERVICE_TAG%"
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

REM ============================================
REM Then add %PWD_ARG% to each CCTK command, e.g.:
REM "%CCTK%" --SecureBoot=Disabled %PWD_ARG%
REM ============================================
