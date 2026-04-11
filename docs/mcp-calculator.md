# MCP Tool Support

apfel natively speaks the [https://modelcontextprotocol.io/](https://modelcontextprotocol.io/). Attach tool servers with `--mcp` and apfel discovers tools, executes them, and returns the final answer.

All inference runs on-device with no network calls for the LLM itself. Optional remote MCP tool servers (`--mcp https://...`) do make network calls for tool arguments.

## Quick start

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
# mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number
# tool: multiply({"a": 15, "b": 27}) = 405
# 15 times 27 is 405.
```

No glue code. No manual round-trip. One command.

## All modes

```bash
# CLI - one command, answer out
apfel --mcp ./mcp/calculator/server.py "What is 2 to the power of 10?"

# Server - tools auto-available to all clients
apfel --serve --mcp ./mcp/calculator/server.py

# Chat - tools persist across the conversation
apfel --chat --mcp ./mcp/calculator/server.py

# Multiple MCP servers
apfel --mcp ./calc.py --mcp ./weather.py "What is sqrt(2025)?"

# Slow or remote MCP server - increase timeout (default: 5s, max: 300s)
apfel --mcp-timeout 30 --mcp ./remote-server.py "hello"

# No --mcp = exactly as before. Zero overhead.
apfel "Hello"
```

## Remote MCP servers

Remote MCP uses Streamable HTTP transport (MCP spec `2025-03-26`):

```bash
# Remote MCP server over HTTPS
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# With bearer token auth - prefer the env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."
apfel --mcp https://mcp.example.com/v1 --mcp-token mytoken "..."

# Mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Security:** Prefer `APFEL_MCP_TOKEN` over `--mcp-token` because CLI flags are visible in `ps aux`. apfel refuses to send a bearer token over plaintext `http://`; use `https://`.

## Calculator tools

Ships at `mcp/calculator/server.py`. Zero dependencies (Python stdlib only).

| Tool | Example | Result |
|------|---------|--------|
| `add` | add(a=10, b=3) | 13 |
| `subtract` | subtract(a=10, b=3) | 7 |
| `multiply` | multiply(a=247, b=83) | 20501 |
| `divide` | divide(a=1000, b=7) | 142.857... |
| `sqrt` | sqrt(a=2025) | 45 |
| `power` | power(a=2, b=10) | 1024 |
| `round_number` | round_number(a=3.14159, decimals=2) | 3.14 |

## Real examples

Five real round trips, unedited.

```
$ apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
tool: multiply({"a": 15, "b": 27}) = 405
15 times 27 is 405.

$ apfel --mcp ./mcp/calculator/server.py "What is the square root of 2025?"
tool: sqrt({"number": 2025}) = 45
The square root of 2025 is 45.

$ apfel --mcp ./mcp/calculator/server.py "Divide 1000 by 7"
tool: divide({"numerator": 1000, "denominator": 7}) = 142.857...
When you divide 1000 by 7, the result is approximately 142.857.

$ apfel --mcp ./mcp/calculator/server.py "What is 2 to the power of 10?"
tool: power({"base": 2, "exponent": 10}) = 1024
2 to the power of 10 is 1024.

$ apfel --mcp ./mcp/calculator/server.py "Add 999 and 1"
tool: add({"a": 999, "b": 1}) = 1000
The result of adding 999 and 1 is 1000.
```

Note: the model sends different argument key names each time (`a`/`b`, `number`, `base`/`exponent`, `numerator`/`denominator`). The calculator handles all of these by extracting numbers from any key.

## How it works

```
apfel --mcp ./calc.py "What is 15 times 27?"
  |
  v
1. Spawn MCP server (stdio subprocess)
2. Initialize (JSON-RPC handshake)
3. tools/list -> discover: add, subtract, multiply, divide, sqrt, power, round_number
  |
  v
4. Ask Apple's LLM with tools defined
5. Model returns: multiply({"a": 15, "b": 27})
  |
  v
6. tools/call via MCP -> result: 20501
  |
  v
7. Re-prompt model with full conversation context + tool result
8. Model answers: "15 times 27 is 405."
```

## Server mode

When running `apfel --serve --mcp ./calc.py`, the server auto-injects MCP tools for clients that don't send their own:

- Client sends tools -> client's tools used, returned as `finish_reason: "tool_calls"` (standard OpenAI behavior, client handles execution)
- Client sends NO tools -> MCP tools injected, server auto-executes tool calls and returns the final text answer with `finish_reason: "stop"`

MCP auto-execution preserves full conversation context: the server appends the tool call and result as proper `assistant`/`tool` messages before re-prompting, so multi-turn conversations work correctly.

## Build your own MCP server

A minimal MCP server is a Python script that reads JSON-RPC from stdin and writes to stdout:

```python
#!/usr/bin/env python3
import json, sys

def read():
    line = sys.stdin.readline()
    return json.loads(line.strip()) if line else None

def send(msg):
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()

def respond(id, result):
    send({"jsonrpc": "2.0", "id": id, "result": result})

while True:
    msg = read()
    if not msg:
        break
    method = msg.get("method", "")
    id = msg.get("id")

    if method == "initialize":
        respond(id, {
            "protocolVersion": "2025-06-18",
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "my-tool", "version": "1.0.0"}
        })
    elif method == "notifications/initialized":
        pass
    elif method == "tools/list":
        respond(id, {"tools": [{
            "name": "my_tool",
            "description": "What it does",
            "inputSchema": {
                "type": "object",
                "properties": {"input": {"type": "string"}},
                "required": ["input"]
            }
        }]})
    elif method == "tools/call":
        args = msg["params"]["arguments"]
        result = "your result here"
        respond(id, {
            "content": [{"type": "text", "text": result}],
            "isError": False
        })
    elif method == "ping":
        respond(id, {})
```

Then use it:

```bash
apfel --mcp ./my-tool.py "question that needs the tool"
```

## Tips for Apple's ~3B model

- **Use multiple simple tools** instead of one complex tool. The model picks function names well but improvises argument structures.
- **Keep descriptions short** with an example: `"Add two numbers. Example: add(a=10, b=3) returns 13"`.
- **Use simple types.** `number` and `string` work best. Nested objects and enums are unreliable.
- **Tolerate improvised keys.** The model might send `{"number1": 5}` instead of `{"a": 5}`.
- **Name tools as verbs.** `multiply`, `search`, `translate` - not `math_operation`.

## Limitations

- **4096 token context window.** Tool definitions, question, tool result, and final answer must all fit.
- **One tool call per turn.** Multi-tool chains require multiple round trips.
- **No guaranteed schema compliance.** The model follows schemas loosely. Your server must handle unexpected argument formats.
- **No streaming for tool calls.** Tool call responses are always non-streaming.
- **Default 5s timeout.** MCP startup and tool calls timeout after 5 seconds. Use `--mcp-timeout <seconds>` or `APFEL_MCP_TIMEOUT` for slow/remote servers.
- **Safety guardrails apply.** Apple's content filters can block tool calls containing flagged words.

## MCP protocol reference

Transport: stdio (JSON-RPC 2.0, one message per line).

| Method | Direction | Response |
|--------|-----------|----------|
| `initialize` | client -> server | Required |
| `notifications/initialized` | client -> server | None (notification) |
| `tools/list` | client -> server | Required |
| `tools/call` | client -> server | Required |
| `ping` | client -> server | Empty result |

See `mcp/calculator/server.py` for a complete working example.
