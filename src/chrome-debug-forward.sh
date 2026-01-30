#!/usr/bin/env bash
set -euo pipefail

# This script forwards the Chrome remote debugging port from a Windows host
# to the local WSL environment. It automatically detects the Windows host IP
# via the default gateway and uses socat to bridge the debugging connection,
# allowing Linux-based tools to interact with Chrome running on Windows.
#
# It continuously monitors for Chrome availability, ensuring the connection
# remains functional even if Chrome is not currently running or is restarted.

PORT=9222
BIND_ADDR=127.0.0.1
LOCK_FILE="/tmp/chrome-debug-forward.lock"

# Prevent multiple instances
exec 9>"${LOCK_FILE}" || exit 1
flock -n 9 || {
  echo "chrome-debug-forward already running"
  exit 0
}

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [chrome-debug-forward] $*"
}

log "Starting Chrome debug forwarder"

while true; do
  # Windows host = WSL default gateway
  WINDOWS_HOST="$(ip route | awk '/^default/ { print $3; exit }')"

  log "Waiting for Chrome on ${WINDOWS_HOST}:${PORT}"

  # Wait until Chrome debug port is actually listening
  until nc -z "${WINDOWS_HOST}" "${PORT}" 2>/dev/null; do
    sleep 0.5
  done

  log "Chrome detected; starting socat"

  socat \
    TCP-LISTEN:${PORT},bind=${BIND_ADDR},fork,reuseaddr \
    TCP:${WINDOWS_HOST}:${PORT}

  log "socat exited (Chrome likely restarted); rearming"
  sleep 0.5
done