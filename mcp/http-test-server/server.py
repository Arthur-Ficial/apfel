#!/usr/bin/env python3
"""
apfel-calc-http - MCP calculator server over Streamable HTTP transport

Same tools as mcp/calculator/server.py but served over HTTP instead of stdio.
Useful for testing apfel's remote MCP support.

Transport: Streamable HTTP (MCP spec 2025-03-26)
Protocol: MCP 2025-06-18

Usage:
    python3 mcp/http-test-server/server.py [--port 8765] [--token mytoken]

Then test with:
    apfel --mcp http://localhost:8765/mcp "what is 247 multiplied by 83?"
    apfel --mcp http://localhost:8765/mcp --mcp-token mytoken "what is sqrt of 144?"
"""

import argparse
import json
import math
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PROTOCOL_VERSION = "2025-06-18"
SERVER_NAME = "apfel-calc-http"
SERVER_VERSION = "1.0.0"

NUM_SCHEMA = {"type": "number"}

TOOLS = [
    {
        "name": "add",
        "description": "Add two numbers. Example: add(a=10, b=3) returns 13",
        "inputSchema": {
            "type": "object",
            "properties": {"a": NUM_SCHEMA, "b": NUM_SCHEMA},
            "required": ["a", "b"]
        }
    },
    {
        "name": "subtract",
        "description": "Subtract b from a. Example: subtract(a=10, b=3) returns 7",
        "inputSchema": {
            "type": "object",
            "properties": {"a": NUM_SCHEMA, "b": NUM_SCHEMA},
            "required": ["a", "b"]
        }
    },
    {
        "name": "multiply",
        "description": "Multiply two numbers. Example: multiply(a=247, b=83) returns 20501",
        "inputSchema": {
            "type": "object",
            "properties": {"a": NUM_SCHEMA, "b": NUM_SCHEMA},
            "required": ["a", "b"]
        }
    },
    {
        "name": "divide",
        "description": "Divide a by b. Example: divide(a=10, b=3) returns 3.3333",
        "inputSchema": {
            "type": "object",
            "properties": {"a": NUM_SCHEMA, "b": NUM_SCHEMA},
            "required": ["a", "b"]
        }
    },
    {
        "name": "sqrt",
        "description": "Square root of a number. Example: sqrt(a=144) returns 12",
        "inputSchema": {
            "type": "object",
            "properties": {"a": NUM_SCHEMA},
            "required": ["a"]
        }
    },
    {
        "name": "power",
        "description": "Raise a to the power of b. Example: power(a=2, b=10) returns 1024",
        "inputSchema": {
            "type": "object",
            "properties": {"a": NUM_SCHEMA, "b": NUM_SCHEMA},
            "required": ["a", "b"]
        }
    },
    {
        "name": "round_number",
        "description": "Round a number to n decimal places. Example: round_number(a=3.14159, decimals=2) returns 3.14",
        "inputSchema": {
            "type": "object",
            "properties": {"a": NUM_SCHEMA, "decimals": {"type": "integer"}},
            "required": ["a"]
        }
    },
]


def get_nums(args):
    """Extract numbers from whatever keys the model used."""
    nums = []
    for v in args.values():
        if isinstance(v, (int, float)):
            nums.append(v)
        elif isinstance(v, str):
            try:
                nums.append(float(v) if "." in v else int(v))
            except ValueError:
                pass
        elif isinstance(v, list):
            for item in v:
                if isinstance(item, (int, float)):
                    nums.append(item)
    return nums


def to_num(v):
    """Convert a value to int or float if it is a numeric string."""
    if isinstance(v, (int, float)):
        return v
    if isinstance(v, str):
        try:
            return float(v) if "." in v else int(v)
        except ValueError:
            pass
    return v


def execute(name, args):
    """Execute a tool by name. Tolerates improvised argument keys."""
    nums = get_nums(args)
    a = to_num(args.get("a", nums[0] if nums else 0))
    b = to_num(args.get("b", nums[1] if len(nums) > 1 else 0))

    try:
        if name == "add":
            r = a + b
        elif name == "subtract":
            r = a - b
        elif name == "multiply":
            r = a * b
        elif name == "divide":
            if b == 0:
                return "Error: division by zero"
            r = a / b
        elif name == "sqrt":
            r = math.sqrt(a)
        elif name == "power":
            r = a ** b
        elif name == "round_number":
            decimals = int(args.get("decimals", args.get("n", nums[1] if len(nums) > 1 else 0)))
            r = round(a, decimals)
        else:
            return f"Error: unknown tool '{name}'"

        if isinstance(r, float) and r == int(r) and not math.isinf(r):
            r = int(r)
        return str(r)
    except Exception as e:
        return f"Error: {e}"


def handle_request(body: dict) -> tuple[dict | None, int]:
    """Returns (response_body, http_status)."""
    method = body.get("method", "")
    req_id = body.get("id")
    params = body.get("params", {})

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION}
            }
        }, 200

    if method == "notifications/initialized":
        return None, 202

    if method == "ping":
        return {"jsonrpc": "2.0", "id": req_id, "result": {}}, 200

    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}, 200

    if method == "tools/call":
        name = params.get("name", "")
        args = params.get("arguments", {})
        tool_names = {t["name"] for t in TOOLS}
        if name in tool_names:
            result = execute(name, args)
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [{"type": "text", "text": result}],
                    "isError": result.startswith("Error:")
                }
            }, 200
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32602, "message": f"Unknown tool: {name}"}
        }, 200

    if req_id is not None:
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32601, "message": f"Method not found: {method}"}
        }, 200

    return None, 202


def make_handler(token: str | None, path: str):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            print(f"  {self.address_string()} {format % args}", file=sys.stderr)

        def do_POST(self):
            if self.path != path:
                self.send_response(404)
                self.end_headers()
                return

            if token:
                auth = self.headers.get("Authorization", "")
                if auth != f"Bearer {token}":
                    self.send_response(401)
                    self.end_headers()
                    self.wfile.write(b'{"error":"unauthorized"}')
                    return

            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length)
            try:
                body = json.loads(raw)
            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                return

            response, status = handle_request(body)

            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            if response is not None:
                self.wfile.write(json.dumps(response).encode())

        def do_DELETE(self):
            self.send_response(200)
            self.end_headers()

    return Handler


def main():
    parser = argparse.ArgumentParser(description="MCP calculator server (HTTP transport)")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--token", type=str, default=None, help="Required Bearer token (optional)")
    args = parser.parse_args()

    endpoint = "/mcp"
    print(f"apfel-calc-http running on http://localhost:{args.port}{endpoint}")
    if args.token:
        print(f"Auth: Bearer {args.token}")
    print(f"Tools: {', '.join(t['name'] for t in TOOLS)}")
    print()

    server = HTTPServer(("localhost", args.port), make_handler(args.token, endpoint))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
