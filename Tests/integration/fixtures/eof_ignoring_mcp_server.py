#!/usr/bin/env python3
"""MCP server fixture that ignores stdin EOF after the handshake.

It answers initialize + tools/list, then stops reading stdin and sleeps forever.
Because it never notices its stdin closing, it is NOT cleaned up by EOF when the
parent exits - only an explicit terminate() reaps it. Used to prove apfel awaits
MCP shutdown on exit paths instead of orphaning such a child (issue #246).
"""

import json
import sys
import time


def read_message():
    line = sys.stdin.readline()
    if not line:
        return None
    return json.loads(line.strip())


def send(msg):
    sys.stdout.write(json.dumps(msg, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def respond(msg_id, result):
    send({"jsonrpc": "2.0", "id": msg_id, "result": result})


def main():
    while True:
        msg = read_message()
        if msg is None:
            break
        method = msg.get("method")
        msg_id = msg.get("id")

        if method == "initialize":
            respond(msg_id, {
                "protocolVersion": "2025-06-18",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "eof-ignoring-mcp", "version": "1.0.0"},
            })
        elif method == "notifications/initialized":
            continue
        elif method == "tools/list":
            respond(msg_id, {
                "tools": [{
                    "name": "multiply",
                    "description": "Multiply two numbers",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "a": {"type": "number"},
                            "b": {"type": "number"},
                        },
                        "required": ["a", "b"],
                    },
                }]
            })
            # Stop reading stdin entirely: EOF will never be observed, so only an
            # explicit SIGTERM/SIGKILL from apfel can reap us.
            while True:
                time.sleep(3600)


if __name__ == "__main__":
    main()
