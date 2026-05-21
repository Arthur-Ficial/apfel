#!/usr/bin/env python3
"""
apfel-dev-tools - MCP developer tools server for apfel

Exposes a comprehensive suite of 9 developer utilities as standard MCP tools
so they can be executed dynamically by the apfel agent inside TUI chat mode.

Transport: stdio (JSON-RPC 2.0)
Protocol: MCP 2025-06-18
"""

import json
import subprocess
import sys

PROTOCOL_VERSION = "2025-06-18"
SERVER_NAME = "apfel-dev-tools"
SERVER_VERSION = "1.0.0"

TOOLS = [
    {
        "name": "cmd",
        "description": "Convert plain English requests into highly optimized, safe, single-line terminal commands (e.g. 'find all pngs larger than 2mb and compress them').",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "The natural language instruction."}
            },
            "required": ["query"]
        }
    },
    {
        "name": "oneliner",
        "description": "Generate complex shell pipes and commands from plain English descriptions (e.g. 'list the top 10 most common words in this log file').",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "The plain English request."}
            },
            "required": ["query"]
        }
    },
    {
        "name": "naming",
        "description": "Provide professional, semantic, and standardized naming suggestions for functions, variables, files, classes, or database tables.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "What you want to name, along with context, framework, or language constraints."}
            },
            "required": ["query"]
        }
    },
    {
        "name": "explain",
        "description": "Provide an expert explanation for a complex terminal command, a stack trace/compiler error, or a code snippet.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "The command, error, or code snippet you want explained."}
            },
            "required": ["query"]
        }
    },
    {
        "name": "wtd",
        "description": "Explain the architecture, structure, primary languages, and purpose of a directory (What's This Directory?).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Optional absolute path to the target directory. Defaults to the current active directory."}
            }
        }
    },
    {
        "name": "port",
        "description": "Identify what process, app, or service is using a given network port on the system, including network details.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "port_number": {"type": "string", "description": "The port number to scan (e.g. '3000', '8080')."}
            },
            "required": ["port_number"]
        }
    },
    {
        "name": "process_info",
        "description": "Inspects a running macOS process by its Process ID (PID) to capture CPU/Memory footprints, open files, active internet sockets, and expert agent explanation.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "pid": {"type": "string", "description": "The Process ID (PID) of the target process."}
            },
            "required": ["pid"]
        }
    },
    {
        "name": "daemon_info",
        "description": "Explains a macOS daemon, utility, or process name (e.g. 'mDNSResponder', 'configd') and how it operates internally.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "The exact name of the macOS daemon or system command."}
            },
            "required": ["name"]
        }
    },
    {
        "name": "docs_apple",
        "description": "Smart Apple developer documentation & code helper. Query SwiftUI, Swift, or native frameworks by symbol (e.g. 'SwiftUI Button'), or pass a natural language request (e.g. 'i want to build a View with italic text') to get grounded explanations and code snippets.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "The framework symbol (e.g., 'SwiftUI Button') or natural language query."
                }
            },
            "required": ["query"]
        }
    }
]


def execute(name, args):
    """Execute the corresponding shell script, returning text output."""
    try:
        if name == "cmd":
            query = args.get("query", "")
            if not query:
                return "Error: query argument is required"
            res = subprocess.run(
                ["/Users/bogdan/DEV/apfel/demo/cmd", query],
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        elif name == "oneliner":
            query = args.get("query", "")
            if not query:
                return "Error: query argument is required"
            res = subprocess.run(
                ["/Users/bogdan/DEV/apfel/demo/oneliner", query],
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        elif name == "naming":
            query = args.get("query", "")
            if not query:
                return "Error: query argument is required"
            res = subprocess.run(
                ["/Users/bogdan/DEV/apfel/demo/naming", query],
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        elif name == "explain":
            query = args.get("query", "")
            if not query:
                return "Error: query argument is required"
            res = subprocess.run(
                ["/Users/bogdan/DEV/apfel/demo/explain", query],
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        elif name == "wtd":
            path = args.get("path", "")
            cmd_args = ["/Users/bogdan/DEV/apfel/demo/wtd"]
            if path:
                cmd_args.append(path)
            res = subprocess.run(
                cmd_args,
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        elif name == "port":
            port_number = args.get("port_number", "")
            if not port_number:
                return "Error: port_number argument is required"
            res = subprocess.run(
                ["/Users/bogdan/DEV/apfel/demo/port", port_number],
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        elif name == "process_info":
            pid = str(args.get("pid", ""))
            if not pid:
                return "Error: pid argument is required"
            res = subprocess.run(
                ["/Users/bogdan/DEV/apfel/demo/process", pid],
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        elif name == "daemon_info":
            daemon_name = args.get("name", "")
            if not daemon_name:
                return "Error: name argument is required"
            res = subprocess.run(
                ["/Users/bogdan/DEV/apfel/demo/daemon", daemon_name],
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        elif name == "docs_apple":
            query = args.get("query", "")
            if not query:
                return "Error: query argument is required"
            res = subprocess.run(
                ["/Users/bogdan/DEV/apfel/demo/docs-apple", query],
                capture_output=True,
                text=True
            )
            return (res.stdout + res.stderr).strip()

        else:
            return f"Error: unknown tool '{name}'"

    except Exception as e:
        return f"Error running utility: {e}"


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
