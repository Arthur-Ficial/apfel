# Background Service

Run apfel's OpenAI-compatible server in the background using Homebrew services. Same pattern as Ollama, PostgreSQL, nginx.

## Quick Start

```bash
brew services start apfel
```

The server starts at `http://127.0.0.1:11434` and auto-restarts on crash or login.

## Commands

```bash
brew services start apfel          # Start (auto-starts at login)
brew services stop apfel           # Stop
brew services restart apfel        # Restart
brew services info apfel           # Status
brew services list                 # All services
```

## Logs

```bash
tail -f /opt/homebrew/var/log/apfel.log
```

## Configuration via Environment

apfel reads configuration from environment variables. Set them before starting the service:

```bash
# Custom port
APFEL_PORT=8080 brew services start apfel

# Token authentication
APFEL_TOKEN="my-secret" brew services start apfel
APFEL_TOKEN=$(uuidgen) brew services start apfel

# Attach MCP tool servers (colon-separated paths)
APFEL_MCP="/path/to/server.py" brew services start apfel
APFEL_MCP="/path/a.py:/path/b.py" brew services start apfel

# MCP timeout for slow/remote servers (default: 5s, max: 300s)
APFEL_MCP_TIMEOUT=30 APFEL_MCP="/path/to/remote-server.py" brew services start apfel

# System prompt
APFEL_SYSTEM_PROMPT="Be concise" brew services start apfel

# Custom host (expose to network - see security note below)
APFEL_HOST=0.0.0.0 APFEL_TOKEN=$(uuidgen) brew services start apfel
```

All `APFEL_*` variables: see `apfel --help` under ENVIRONMENT.

## Security

The background service uses the same security model as `apfel --serve`:

- **Default: localhost only.** Binds to `127.0.0.1` unless `APFEL_HOST` overrides.
- **Token auth.** Set `APFEL_TOKEN` for Bearer authentication.
- **When exposing to network** (`APFEL_HOST=0.0.0.0`), always set a token:
  ```bash
  APFEL_HOST=0.0.0.0 APFEL_TOKEN=$(uuidgen) brew services start apfel
  ```

See [Server Security](server-security.md) for full details.

## Manual Plist (Advanced)

For configurations that Homebrew's service doesn't cover (custom flags, complex MCP setups), create a plist manually:

```bash
cat > ~/Library/LaunchAgents/com.arthurficial.apfel.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.arthurficial.apfel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/opt/apfel/bin/apfel</string>
        <string>--serve</string>
        <string>--port</string>
        <string>11434</string>
        <string>--mcp</string>
        <string>/absolute/path/to/server.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/apfel.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/apfel.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>/Users/YOUR_USERNAME</string>
        <key>APFEL_TOKEN</key>
        <string>YOUR_TOKEN</string>
    </dict>
</dict>
</plist>
EOF

# Load
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.arthurficial.apfel.plist

# Unload
launchctl bootout gui/$(id -u)/com.arthurficial.apfel

# Check status
launchctl print gui/$(id -u)/com.arthurficial.apfel
```

Use `/opt/homebrew/opt/apfel/bin/apfel` (not the Cellar path) so it survives `brew upgrade`.

**Keep the log out of `/tmp`.** `/private/tmp` is mode `1777` - world-writable with the sticky bit - and launchd creates the log with the process umask (`0644`) and follows symlinks when opening it. Any local user can read it, and can pre-create the path as a symlink before the service first starts. That matters here because this is the same file the server's request errors land in, and with `--mcp` it is also where MCP tool activity is logged. `~/Library/Logs` is the macOS-conventional location for a user agent's log and is not world-writable.

Replace `YOUR_USERNAME` with your short username (`id -un`) - launchd does not expand `~` or `$HOME` in path keys.
