@echo off
setlocal enabledelayedexpansion

:: ============================================
:: Windows Debug Script for Antigravity Bridge
:: ============================================
:: Checks configuration state and reports issues

echo == Antigravity Bridge - Windows Diagnostics ==
echo.

set "ERRORS=0"
set "WARNINGS=0"

:: --------------------------------
:: Check Chrome wrapper
:: --------------------------------
echo [1/6] Chrome Wrapper
set "WRAPPER=C:\antigravity\chrome\chrome.exe"
if exist "%WRAPPER%" (
    echo      [OK] Wrapper exists: %WRAPPER%
) else (
    echo      [ERROR] Wrapper NOT FOUND: %WRAPPER%
    set /a ERRORS+=1
)
echo.

:: --------------------------------
:: Check real Chrome
:: --------------------------------
echo [2/6] Chrome Installation

set "CHROME_PATH="
set "PATHS[0]=C:\Program Files\Google\Chrome\Application\chrome.exe"
set "PATHS[1]=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
set "PATHS[2]=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"

for /L %%i in (0,1,2) do (
    if exist "!PATHS[%%i]!" (
        set "CHROME_PATH=!PATHS[%%i]!"
    )
)

if defined CHROME_PATH (
    echo      [OK] Chrome found: %CHROME_PATH%
) else (
    echo      [ERROR] Chrome NOT FOUND in standard paths
    set /a ERRORS+=1
)
echo.

:: --------------------------------
:: Check port proxy script
:: --------------------------------
echo [3/6] Port Proxy Script
set "PROXY_SCRIPT=C:\antigravity\wsl-portproxy.ps1"
if exist "%PROXY_SCRIPT%" (
    echo      [OK] Script exists: %PROXY_SCRIPT%
) else (
    echo      [ERROR] Script NOT FOUND: %PROXY_SCRIPT%
    set /a ERRORS+=1
)
echo.

:: --------------------------------
:: Check portproxy rules (requires admin)
:: --------------------------------
echo [4/6] Port Proxy Rules
echo      Checking netsh portproxy...

for /f "tokens=*" %%a in ('netsh interface portproxy show v4tov4 2^>nul ^| findstr "9222"') do (
    set "PROXY_RULE=%%a"
)

if defined PROXY_RULE (
    echo      [OK] Port 9222 rule found:
    echo          %PROXY_RULE%
) else (
    echo      [WARN] No portproxy rule for port 9222
    echo            Run wsl-portproxy.ps1 to configure
    set /a WARNINGS+=1
)
echo.

:: --------------------------------
:: Check firewall
:: --------------------------------
echo [5/6] Firewall Rule
powershell -NoProfile -Command ^
    "$rule = Get-NetFirewallRule -DisplayName 'Antigravity Bridge' -ErrorAction SilentlyContinue; if ($rule) { Write-Host '     [OK] Firewall rule exists: Antigravity Bridge'; Write-Host ('          Enabled: ' + $rule.Enabled) } else { Write-Host '     [WARN] Firewall rule not found'; exit 1 }"

if errorlevel 1 (
    set /a WARNINGS+=1
)
echo.

:: --------------------------------
:: Check Scheduled Task
:: --------------------------------
echo [6/7] Scheduled Task
powershell -NoProfile -Command ^
    "$task = Get-ScheduledTask -TaskName 'Antigravity WSL Port Proxy' -ErrorAction SilentlyContinue; if ($task) { Write-Host '     [OK] Scheduled task exists: Antigravity WSL Port Proxy'; Write-Host ('          State: ' + $task.State) } else { Write-Host '     [WARN] Scheduled task not found'; exit 1 }"

if errorlevel 1 (
    set /a WARNINGS+=1
)
echo.

:: --------------------------------
:: Check Chrome debug port
:: --------------------------------
echo [7/7] Chrome Debug Port
powershell -NoProfile -Command ^
    "$conn = Test-NetConnection -ComputerName 127.0.0.1 -Port 9222 -WarningAction SilentlyContinue; if ($conn.TcpTestSucceeded) { Write-Host '     [OK] Port 9222 is listening' } else { Write-Host '     [INFO] Port 9222 not listening (Chrome may not be running)' }"
echo.

:: --------------------------------
:: Summary
:: --------------------------------
echo ========================================
if %ERRORS% GTR 0 (
    echo RESULT: %ERRORS% error(s), %WARNINGS% warning(s)
    echo Status: FAILED - Run setup-windows.ps1 to fix
) else if %WARNINGS% GTR 0 (
    echo RESULT: %ERRORS% error(s), %WARNINGS% warning(s)  
    echo Status: PARTIAL - Some configuration may be missing
) else (
    echo RESULT: All checks passed
    echo Status: OK
)
echo ========================================
