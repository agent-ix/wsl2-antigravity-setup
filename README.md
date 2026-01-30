# WSL2 Antigravity Browser Bridge

Enable Chrome remote debugging from WSL and Linux containers by bridging the Chrome DevTools Protocol (CDP) from Windows to WSL while retaining separate NAT'd network for WSL.

## Overview

This setup allows tools running inside WSL (like Playwright, Puppeteer, or AI agents) to control a Chrome browser running on the Windows host. This is useful because:

- Chrome debug port binds to `127.0.0.1` which isn't directly accessible from WSL
- Running Chrome inside containers has sandboxing limitations
- You can use the host's authenticated browser sessions

This is an alternative method to using "mirrored" WSL network mode. This method ensures the WSL network is 
isolated and service bound to `0.0.0.0` won't be exposed to the external WAN/LAN. It's an extra layer of 
precaution since agents can start services.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ Windows Host                                                        │
│                                                                     │
│  ┌──────────────────┐     ┌───────────────────────────────────────┐ │
│  │ Chrome Wrapper   │     │ Port Proxy (netsh)                    │ │
│  │ chrome.exe       │────▶│ WSL-IP:9222 → 127.0.0.1:9222          │ │
│  │ --remote-debug   │     └───────────────────────────────────────┘ │
│  │   -port=9222     │                       │                       │
│  └──────────────────┘                       │                       │
└─────────────────────────────────────────────│───────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ WSL / Linux                                                         │
│                                                                     │
│  ┌───────────────────────────────────────┐     ┌──────────────────┐ │
│  │ socat forwarder                       │     │ Your Tools       │ │
│  │ 127.0.0.1:9222 ←→ Windows-IP:9222     │◀───▶│ Playwright, etc  │ │
│  └───────────────────────────────────────┘     └──────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Windows 10/11** with WSL2 enabled
- **Google Chrome** installed on Windows
- **PowerShell** (for Windows setup)
- **Ubuntu/Debian WSL** (other distros may work but untested)

## Quick Start

### 0. Network State
If you're using WSL network is set to "mirrored" mode, you'll need to change it to "private" mode.

### 1. Clone the Repository

```powershell
# On Windows (PowerShell)
git clone https://github.com/agent-ix/wsl2-antigravity-setup.git
cd wsl2-antigravity-setup
```

### 2. Run Windows Setup

Open PowerShell **as Administrator** and run:

```powershell
.\scripts\setup-windows.ps1
```

This will:
- Create `C:\antigravity\chrome\` directory
- Build the Chrome wrapper with debug flags
- Install the port proxy script
- Create a Scheduled Task to run port proxy at login

### 3. Run WSL Setup

Open your WSL terminal and run:

```bash
cd /mnt/c/path/to/wsl2-antigravity-setup
./scripts/setup-wsl.sh
```

This will:
- Install `socat` and `netcat` dependencies
- Install the port forwarder to `/usr/local/bin/`
- Create a systemd user service for automatic startup

### 4. Start the Services

**Windows** (run once, or reboot to use Scheduled Task):
```powershell
& "C:\antigravity\wsl-portproxy.ps1"
```

**WSL**:
```bash
systemctl --user start chrome-debug-forward
```

### 5. Use Chrome with Remote Debugging

Launch Chrome using the wrapper:
```powershell
& "C:\antigravity\chrome\chrome.exe"
```

## Verification

### Check Windows Status

```batch
scripts\debug-windows.bat
```

### Check WSL Status

```bash
./scripts/debug-wsl.sh
```

### Test Connectivity

From WSL, verify Chrome is accessible:
```bash
curl http://127.0.0.1:9222/json/version
```

You should see JSON output with Chrome version info.

## Troubleshooting

### Port 9222 not listening on Windows

- Make sure Chrome is running with the wrapper: `C:\antigravity\chrome\chrome.exe`
- Check if another Chrome instance is already running (close all Chrome windows first)

### Port proxy not configured

Run the port proxy script manually:
```powershell
& "C:\antigravity\wsl-portproxy.ps1"
```

### WSL can't reach Windows host

1. Check firewall rule exists: `debug-windows.bat`
2. Verify WSL IP detection: The script should show the detected IP

### Forwarder not running in WSL

Start it manually:
```bash
/usr/local/bin/chrome-debug-forward.sh &
```

Or via systemd:
```bash
systemctl --user start chrome-debug-forward
systemctl --user status chrome-debug-forward
```

## Files

| File | Description |
|------|-------------|
| `src/chrome-wrapper.cs` | C# source for Chrome launcher with debug flags |
| `src/chrome-debug-forward.sh` | WSL port forwarder using socat |
| `src/wsl-portproxy.ps1` | Windows port proxy configuration |
| `scripts/setup-windows.ps1` | Windows installation script |
| `scripts/setup-wsl.sh` | WSL installation script |
| `scripts/build-chrome-wrapper.bat` | Compiles Chrome wrapper |
| `scripts/debug-windows.bat` | Windows diagnostic script |
| `scripts/debug-wsl.sh` | WSL diagnostic script |

## License

MIT
