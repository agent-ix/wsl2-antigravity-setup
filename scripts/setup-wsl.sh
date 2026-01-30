#!/usr/bin/env bash
set -euo pipefail

# ============================================
# WSL Setup Script for Antigravity Bridge
# ============================================

echo "== Antigravity Bridge - WSL Setup =="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$REPO_ROOT/src"

INSTALL_BIN="/usr/local/bin"
SERVICE_NAME="chrome-debug-forward"
FORWARDER_SRC="$SRC_DIR/chrome-debug-forward.sh"
FORWARDER_DST="$INSTALL_BIN/chrome-debug-forward"

# --------------------------------
# Check for root
# --------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "This script requires root. Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# --------------------------------
# Install dependencies
# --------------------------------
echo "[1/4] Installing dependencies..."

DEPS=(socat netcat-openbsd)
MISSING=()

for pkg in "${DEPS[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "      Installing: ${MISSING[*]}"
    apt-get update -qq
    apt-get install -y -qq "${MISSING[@]}"
else
    echo "      All dependencies installed"
fi
echo ""

# --------------------------------
# Install forwarder script
# --------------------------------
echo "[2/4] Installing forwarder script..."

cp "$FORWARDER_SRC" "$FORWARDER_DST"
chmod +x "$FORWARDER_DST"
echo "      Installed: $FORWARDER_DST"
echo ""

# --------------------------------
# Create systemd user service
# --------------------------------
echo "[3/4] Configuring systemd service..."

# Get the actual user (not root from sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
USER_SERVICE_DIR="$ACTUAL_HOME/.config/systemd/user"

mkdir -p "$USER_SERVICE_DIR"

cat > "$USER_SERVICE_DIR/$SERVICE_NAME.service" << EOF
[Unit]
Description=Chrome Debug Port Forwarder
After=network.target

[Service]
Type=simple
ExecStart=$FORWARDER_DST
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.config/systemd"
echo "      Created: $USER_SERVICE_DIR/$SERVICE_NAME.service"

# Enable and start as user
echo "      Enabling service for user: $ACTUAL_USER"
sudo -u "$ACTUAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
    systemctl --user daemon-reload 2>/dev/null || true
sudo -u "$ACTUAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
    systemctl --user enable "$SERVICE_NAME" 2>/dev/null || true

echo ""

# --------------------------------
# Summary
# --------------------------------
echo "[4/4] Setup complete!"
echo ""
echo "Installed components:"
echo "  - Forwarder:  $FORWARDER_DST"
echo "  - Service:    $USER_SERVICE_DIR/$SERVICE_NAME.service"
echo ""
echo "To start the forwarder now:"
echo "  systemctl --user start $SERVICE_NAME"
echo ""
echo "To check status:"
echo "  systemctl --user status $SERVICE_NAME"
echo ""
echo "Or run directly:"
echo "  $FORWARDER_DST &"
echo ""
