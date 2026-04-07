# Background Service

Run apfel's OpenAI-compatible server as a per-user macOS background service.

No terminal window needed. The service uses `launchd` and starts again when you log in.

## Install

```bash
apfel service install
```

Default endpoint:

```text
http://127.0.0.1:11434
```

Custom port:

```bash
apfel service install --port 11435
```

Re-run `install` any time to update the saved config. It rewrites the config file and reloads the service.

## Status

```bash
apfel service status
```

Shows:

- current status
- endpoint
- config path
- LaunchAgent plist path
- log directory

## Logs

Logs live under:

```text
~/Library/Logs/apfel/
```

Files:

```text
service.stdout.log
service.stderr.log
```

Tail them:

```bash
tail -f ~/Library/Logs/apfel/service.stderr.log
```

## Security

Add a token when installing:

```bash
apfel service install --token "my-secret-token"
```

Or generate one once and persist it:

```bash
apfel service install --token-auto
```

`--token-auto` prints the generated token during install. Later restarts keep the same saved token.

For background services that only serve the local machine, the default bind remains:

```text
127.0.0.1
```

If you bind to `0.0.0.0`, also add a token:

```bash
apfel service install --host 0.0.0.0 --token-auto
```

See [server-security.md](server-security.md) for the full security model.

## MCP servers

Attach MCP servers the same way as normal server mode:

```bash
apfel service install --mcp ./mcp/calculator/server.py
```

Relative paths are resolved when you run `install`, then saved as absolute paths in the config file.

## Stop / Start / Restart / Uninstall

```bash
apfel service stop
apfel service start
apfel service restart
apfel service uninstall
```

`uninstall` removes the LaunchAgent but keeps `~/Library/Application Support/apfel/server.json`.

## Files

Config:

```text
~/Library/Application Support/apfel/server.json
```

LaunchAgent:

```text
~/Library/LaunchAgents/com.arthurficial.apfel.plist
```

## Common cases

Local default:

```bash
apfel service install
```

Frontend dev server on another port:

```bash
apfel service install --port 11435 --cors --allowed-origins "http://localhost:3000"
```

LAN access:

```bash
apfel service install --host 0.0.0.0 --token-auto --public-health
```
