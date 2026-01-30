# ================================
# WSL Port Proxy Auto Configuration
# ================================

# This script configures a port proxy between the WSL environment and the Windows host.
# It automatically detects the WSL IP address and sets up the port proxy to forward
# the specified port to the Windows host.

$ListenPort = 9222
$RuleName   = "Antigravity Bridge"

Write-Host "== WSL Port Proxy Setup =="
Write-Host "Port        : $ListenPort"
Write-Host "Firewall    : $RuleName"
Write-Host ""

# --------------------------------
# Initialize WSL networking
# --------------------------------

Write-Host "[1/5] Initializing WSL networking..."
wsl.exe -e true 2>$null
Write-Host "     OK WSL initialization invoked"

# --------------------------------
# Discover WSL IP
# --------------------------------

Write-Host "[2/5] Discovering WSL vEthernet IPv4 address..."

$WslIp = $null
for ($i = 1; $i -le 10 -and -not $WslIp; $i++) {
    Write-Host "     Attempt $i..."

    $WslIp = Get-NetIPAddress `
        -AddressFamily IPv4 `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -like "*WSL*" -and
            $_.IPAddress -notlike "169.254*"
        } |
        Select-Object -First 1 -ExpandProperty IPAddress

    if (-not $WslIp) {
        Start-Sleep -Seconds 2
    }
}

if (-not $WslIp) {
    Write-Error "WSL IP not found after waiting"
    exit 1
}

Write-Host "     OK WSL IP detected: $WslIp"
Write-Host ""

# --------------------------------
# Portproxy configuration
# --------------------------------

Write-Host "[3/5] Configuring port proxy..."

Write-Host "     Removing stale portproxy rules (if any)..."
cmd /c "netsh interface portproxy delete v4tov4 listenport=$ListenPort listenaddress=0.0.0.0" >$null 2>&1
cmd /c "netsh interface portproxy delete v4tov4 listenport=$ListenPort listenaddress=$WslIp" >$null 2>&1
Write-Host "     OK Cleanup complete"

Write-Host "     Adding portproxy rule:"
Write-Host "       ${WslIp}:${ListenPort} -> 127.0.0.1:${ListenPort}"

netsh interface portproxy add v4tov4 `
    listenaddress=$WslIp `
    listenport=$ListenPort `
    connectaddress=127.0.0.1 `
    connectport=$ListenPort

Write-Host "     OK Portproxy rule installed"
Write-Host ""

# --------------------------------
# Firewall configuration
# --------------------------------

Write-Host "[4/5] Configuring Windows Firewall..."

$FirewallRule = Get-NetFirewallRule `
    -DisplayName $RuleName `
    -ErrorAction SilentlyContinue

if (-not $FirewallRule) {
    Write-Host "     Creating firewall rule:"
    Write-Host "       Name    : $RuleName"
    Write-Host "       Port    : $ListenPort"
    Write-Host "       Address : $WslIp"

    New-NetFirewallRule `
        -DisplayName $RuleName `
        -Direction Inbound `
        -LocalPort $ListenPort `
        -Protocol TCP `
        -Action Allow `
        -Profile Any `
        -LocalAddress $WslIp

    Write-Host "     OK Firewall rule created"
}
else {
    Write-Host "     Updating existing firewall rule:"
    Write-Host "       Name    : $RuleName"
    Write-Host "       Address : $WslIp"

    Set-NetFirewallRule `
        -DisplayName $RuleName `
        -LocalAddress $WslIp

    Write-Host "     OK Firewall rule updated"
}

Write-Host ""

# --------------------------------
# Summary
# --------------------------------

Write-Host "[5/5] Configuration complete"
Write-Host "     Portproxy : ${WslIp}:${ListenPort} -> 127.0.0.1:${ListenPort}"
Write-Host "     Firewall  : $RuleName (Inbound TCP $ListenPort)"
Write-Host ""
Write-Host "WSL port proxy configured successfully."
