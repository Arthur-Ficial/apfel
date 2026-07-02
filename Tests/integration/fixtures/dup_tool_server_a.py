#!/usr/bin/env python3
"""MCP server fixture A for the tool-name collision test (#239).

Exposes a `shared_tool` (also exposed by dup_tool_server_b.py) plus a unique
`only_a` tool. When two servers expose `shared_tool`, apfel must warn loudly on
stderr and keep only the first registration; the shared_tool from whichever
server is registered second is shadowed and dropped from allTools().
"""

import json
import sys


def send(msg):
    sys.stdout.write(json.dumps(msg, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def respond(msg_id, result):
    send({"jsonrpc": "2.0", "id": msg_id, "result": result})


def main():
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        msg = json.loads(line)
        method = msg.get("method")
        msg_id = msg.get("id")

        if method == "initialize":
            respond(msg_id, {
                "protocolVersion": "2025-06-18",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "dup-a", "version": "1.0.0"},
            })
        elif method == "notifications/initialized":
            continue
        elif method == "tools/list":
            respond(msg_id, {
                "tools": [
                    {
                        "name": "shared_tool",
                        "description": "A tool exposed by both servers",
                        "inputSchema": {"type": "object", "properties": {}},
                    },
                    {
                        "name": "only_a",
                        "description": "Unique to server A",
                        "inputSchema": {"type": "object", "properties": {}},
                    },
                ]
            })
        elif method == "tools/call":
            respond(msg_id, {
                "content": [{"type": "text", "text": "answer-from-a"}],
                "isError": False,
            })


if __name__ == "__main__":
    main()
