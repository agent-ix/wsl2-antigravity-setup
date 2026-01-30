# ============================================
# Windows Setup Script for Antigravity Bridge
# ============================================
# Run this script in PowerShell as Administrator

param(
    [switch]$SkipScheduledTask
)

$ErrorActionPreference = "Stop"

Write-Host "== Antigravity Bridge - Windows Setup ==" -ForegroundColor Cyan
Write-Host ""

# --------------------------------
# Get paths
# --------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$SrcDir = Join-Path $RepoRoot "src"
$InstallDir = "C:\antigravity"
$ChromeDir = Join-Path $InstallDir "chrome"

# --------------------------------
# Create directories
# --------------------------------
Write-Host "[1/5] Creating directories..."

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "      Created: $InstallDir"
} else {
    Write-Host "      Exists: $InstallDir"
}

if (-not (Test-Path $ChromeDir)) {
    New-Item -ItemType Directory -Path $ChromeDir -Force | Out-Null
    Write-Host "      Created: $ChromeDir"
} else {
    Write-Host "      Exists: $ChromeDir"
}
Write-Host ""

# --------------------------------
# Copy portproxy script
# --------------------------------
Write-Host "[2/5] Installing port proxy script..."

$PortProxySrc = Join-Path $SrcDir "wsl-portproxy.ps1"
$PortProxyDst = Join-Path $InstallDir "wsl-portproxy.ps1"

Copy-Item -Path $PortProxySrc -Destination $PortProxyDst -Force
Write-Host "      Installed: $PortProxyDst"
Write-Host ""

# --------------------------------
# Build Chrome wrapper
# --------------------------------
Write-Host "[3/5] Building Chrome wrapper..."

$BuildScript = Join-Path $ScriptDir "build-chrome-wrapper.bat"
& cmd /c "$BuildScript"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Chrome wrapper build failed"
    exit 1
}
Write-Host ""

# --------------------------------
# Create Scheduled Task
# --------------------------------
Write-Host "[4/5] Configuring startup task..."

if ($SkipScheduledTask) {
    Write-Host "      Skipped (flag set)"
} else {
    $TaskName = "Antigravity WSL Port Proxy"
    $TaskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    # PowerShell command to run at logon
    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PortProxyDst`""

    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    if ($TaskExists) {
        Write-Host "      Updating existing task: $TaskName"
        Set-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings | Out-Null
    } else {
        Write-Host "      Creating task: $TaskName"
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings | Out-Null
    }
    Write-Host "      OK Task configured to run at logon"
}
Write-Host ""

# --------------------------------
# Summary
# --------------------------------
Write-Host "[5/5] Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Installed components:"
Write-Host "  - Chrome wrapper:  $ChromeDir\chrome.exe"
Write-Host "  - Port proxy:      $PortProxyDst"
Write-Host "  - Scheduled Task:  Antigravity WSL Port Proxy"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run the port proxy now: & '$PortProxyDst'"
Write-Host "  2. Run setup-wsl.sh inside WSL"
Write-Host "  3. Configure Antigravity browser command to $ChromeDir\chrome.exe"
Write-Host ""
