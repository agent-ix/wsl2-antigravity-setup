@echo off
setlocal enabledelayedexpansion

:: ============================================
:: Chrome Wrapper Build Script
:: ============================================
:: Auto-detects Chrome installation and compiles
:: the wrapper with the correct path embedded.

echo == Chrome Wrapper Build ==
echo.

:: Get script directory (repo root is one level up)
set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "SRC_FILE=%REPO_ROOT%\src\chrome-wrapper.cs"
set "OUT_DIR=C:\antigravity\chrome"
set "OUT_FILE=%OUT_DIR%\chrome.exe"
set "TEMP_CS=%OUT_DIR%\chrome-wrapper.cs"

:: --------------------------------
:: Find Chrome installation
:: --------------------------------
echo [1/4] Searching for Chrome installation...

set "CHROME_PATH="

:: Check common installation paths
set "PATHS[0]=C:\Program Files\Google\Chrome\Application\chrome.exe"
set "PATHS[1]=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
set "PATHS[2]=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"

for /L %%i in (0,1,2) do (
    if exist "!PATHS[%%i]!" (
        set "CHROME_PATH=!PATHS[%%i]!"
        goto :found
    )
)

:: Not found in common paths
echo ERROR: Chrome not found in common installation paths.
echo Searched:
for /L %%i in (0,1,2) do echo   - !PATHS[%%i]!
exit /b 1

:found
echo      Found: %CHROME_PATH%
echo.

:: --------------------------------
:: Create output directory
:: --------------------------------
echo [2/4] Creating output directory...

if not exist "%OUT_DIR%" (
    mkdir "%OUT_DIR%"
    echo      Created: %OUT_DIR%
) else (
    echo      Exists: %OUT_DIR%
)
echo.

:: --------------------------------
:: Generate source with Chrome path
:: --------------------------------
echo [3/4] Generating source file...

:: Read template and substitute Chrome path
:: Use PowerShell for reliable string replacement
powershell -NoProfile -Command ^
    "(Get-Content -Raw '%SRC_FILE%') -replace '\{\{CHROME_PATH\}\}', '%CHROME_PATH%' | Set-Content -NoNewline '%TEMP_CS%'"

if errorlevel 1 (
    echo ERROR: Failed to generate source file
    exit /b 1
)
echo      Generated: %TEMP_CS%
echo.

:: --------------------------------
:: Compile
:: --------------------------------
echo [4/4] Compiling...

set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if not exist "%CSC%" (
    echo ERROR: C# compiler not found at %CSC%
    exit /b 1
)

"%CSC%" /nologo /out:"%OUT_FILE%" "%TEMP_CS%"

if errorlevel 1 (
    echo ERROR: Compilation failed
    exit /b 1
)

echo      Compiled: %OUT_FILE%
echo.

:: --------------------------------
:: Done
:: --------------------------------
echo == Build Complete ==
echo Chrome wrapper installed to: %OUT_FILE%
echo.
echo To use: Replace Chrome shortcuts or add %OUT_DIR% to PATH