#!/usr/bin/env bash
set -uo pipefail

# ============================================
# WSL Debug Script for Antigravity Bridge
# ============================================
# Checks configuration state and reports issues

echo "== Antigravity Bridge - WSL Diagnostics =="
echo ""

ERRORS=0
WARNINGS=0

ok()   { echo "     [OK] $*"; }
warn() { echo "     [WARN] $*"; ((WARNINGS++)); }
err()  { echo "     [ERROR] $*"; ((ERRORS++)); }
info() { echo "     [INFO] $*"; }

# --------------------------------
# Check dependencies
# --------------------------------
echo "[1/6] Dependencies"

for pkg in socat nc curl; do
    if command -v "$pkg" &>/dev/null; then
        ok "$pkg installed: $(command -v "$pkg")"
    else
        case "$pkg" in
            nc) err "$pkg NOT FOUND - install with: apt install netcat-openbsd" ;;
            *)  err "$pkg NOT FOUND - install with: apt install $pkg" ;;
        esac
    fi
done
echo ""

# --------------------------------
# Check forwarder script
# --------------------------------
echo "[2/6] Forwarder Script"

FORWARDER="/usr/local/bin/chrome-debug-forward"
if [[ -x "$FORWARDER" ]]; then
    ok "Script installed: $FORWARDER"
else
    if [[ -f "$FORWARDER" ]]; then
        warn "Script exists but not executable: $FORWARDER"
    else
        err "Script NOT FOUND: $FORWARDER"
    fi
fi
echo ""

# --------------------------------
# Check systemd service
# --------------------------------
echo "[3/6] Systemd Service"

SERVICE_NAME="chrome-debug-forward"
USER_SERVICE="$HOME/.config/systemd/user/$SERVICE_NAME.service"

if [[ -f "$USER_SERVICE" ]]; then
    ok "Service file exists: $USER_SERVICE"
    
    # Check if enabled
    if systemctl --user is-enabled "$SERVICE_NAME" &>/dev/null; then
        ok "Service is enabled"
    else
        warn "Service exists but not enabled"
    fi
    
    # Check if running
    if systemctl --user is-active "$SERVICE_NAME" &>/dev/null; then
        ok "Service is running"
    else
        info "Service is not running"
    fi
else
    warn "Service file not found: $USER_SERVICE"
fi
echo ""

# --------------------------------
# Check Windows host connectivity
# --------------------------------
echo "[4/6] Windows Host"

WINDOWS_HOST="$(ip route | awk '/^default/ { print $3; exit }')"
if [[ -n "$WINDOWS_HOST" ]]; then
    ok "Windows host IP: $WINDOWS_HOST"
    
    if ping -c 1 -W 1 "$WINDOWS_HOST" &>/dev/null; then
        ok "Host is reachable"
    else
        err "Host is NOT reachable"
    fi
else
    err "Could not determine Windows host IP"
fi
echo ""

# --------------------------------
# Check remote debug port on Windows
# --------------------------------
echo "[5/6] Chrome Debug Port (Windows side)"

if [[ -n "$WINDOWS_HOST" ]]; then
    if nc -z -w 2 "$WINDOWS_HOST" 9222 2>/dev/null; then
        ok "Port 9222 open on Windows host ($WINDOWS_HOST)"
    else
        info "Port 9222 not open on Windows (Chrome may not be running)"
    fi
else
    warn "Skipped - Windows host unknown"
fi
echo ""

# --------------------------------
# Check local forwarded port
# --------------------------------
echo "[6/6] Local Forwarded Port"

if nc -z 127.0.0.1 9222 2>/dev/null; then
    ok "Port 9222 listening on localhost"
    
    # Try to get Chrome version
    VERSION=$(curl -s http://127.0.0.1:9222/json/version 2>/dev/null | grep -o '"Browser":"[^"]*"' | head -1)
    if [[ -n "$VERSION" ]]; then
        ok "Chrome responding: $VERSION"
    fi
else
    info "Port 9222 not listening locally"
    info "Start forwarder: $FORWARDER &"
fi
echo ""

# --------------------------------
# Summary
# --------------------------------
echo "========================================"
if [[ $ERRORS -gt 0 ]]; then
    echo "RESULT: $ERRORS error(s), $WARNINGS warning(s)"
    echo "Status: FAILED - Run setup-wsl.sh to fix"
elif [[ $WARNINGS -gt 0 ]]; then
    echo "RESULT: $ERRORS error(s), $WARNINGS warning(s)"
    echo "Status: PARTIAL - Some configuration may be missing"
else
    echo "RESULT: All checks passed"
    echo "Status: OK"
fi
echo "========================================"
