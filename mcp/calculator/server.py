#!/usr/bin/env python3
"""
apfel-calc - MCP calculator server for Apple Intelligence

A standards-compliant Model Context Protocol server that gives
Apple's on-device LLM the ability to do math.

Multiple simple tools instead of one complex one - the ~3B model
picks function names reliably but improvises argument structures.

Transport: stdio (JSON-RPC 2.0)
Protocol: MCP 2025-06-18

Usage with Claude Desktop / Claude Code:
  {
    "mcpServers": {
      "calculator": {
        "command": "python3",
        "args": ["/path/to/apfel/mcp/calculator/server.py"]
      }
    }
  }
"""

import json
import math
import sys

PROTOCOL_VERSION = "2025-06-18"
SERVER_NAME = "apfel-calc"
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
    """Coerce a value to a number. The on-device model routinely emits string
    arguments; without coercion, add("999","1") string-concatenates to "9991"."""
    if isinstance(v, (int, float)):
        return v
    if isinstance(v, str):
        try:
            return float(v) if "." in v else int(v)
        except ValueError:
            pass
    raise TypeError(f"not a number: {v!r}")


def execute(name, args):
    """Execute a tool by name. Tolerates improvised argument keys."""
    nums = get_nums(args)
    a = args.get("a", nums[0] if nums else 0)
    b = args.get("b", nums[1] if len(nums) > 1 else 0)

    try:
        a = to_num(a)
        b = to_num(b)
    except TypeError as e:
        return f"Error: {e}"

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


def error(msg_id, code, message):
    send({"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}})


def handle(msg):
    method = msg.get("method", "")
    msg_id = msg.get("id")
    params = msg.get("params", {})

    if method == "initialize":
        respond(msg_id, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION}
        })
    elif method == "notifications/initialized":
        pass
    elif method == "tools/list":
        respond(msg_id, {"tools": TOOLS})
    elif method == "tools/call":
        name = params.get("name", "")
        args = params.get("arguments", {})
        tool_names = {t["name"] for t in TOOLS}
        if name in tool_names:
            result = execute(name, args)
            respond(msg_id, {
                "content": [{"type": "text", "text": result}],
                "isError": result.startswith("Error:")
            })
        else:
            error(msg_id, -32602, f"Unknown tool: {name}")
    elif method == "ping":
        respond(msg_id, {})
    elif msg_id is not None:
        error(msg_id, -32601, f"Method not found: {method}")


def main():
    while True:
        msg = read_message()
        if msg is None:
            break
        handle(msg)


if __name__ == "__main__":
    main()
