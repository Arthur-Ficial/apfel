#!/usr/bin/env python3
"""
Full tool-calling round trip: apfel --serve + HTTP MCP calculator.

Mirrors mcp/calculator/test_round_trip.py but uses the HTTP MCP server
instead of the stdio calculator. The apfel server auto-executes MCP tools
internally, so a single /v1/chat/completions request returns the final answer.

Prerequisites:
    pip install httpx

Usage:
    # Terminal 1: start the HTTP calc server
    python3 mcp/http-test-server/server.py [--port 8765] [--token TOKEN]

    # Terminal 2: start the apfel server with the HTTP MCP server attached
    apfel --serve --port 11436 --mcp http://localhost:8765/mcp [--mcp-token TOKEN]

    # Terminal 3: run this test
    python3 mcp/http-test-server/test_round_trip.py [apfel_port] [question]
"""

import re
import sys
import time

import httpx

APFEL_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 11436
QUESTION   = sys.argv[2] if len(sys.argv) > 2 else "What is 247 times 83?"

BASE = f"http://localhost:{APFEL_PORT}"
API  = f"{BASE}/v1"
TIMEOUT = 120


def wait_for_server(base_url: str, timeout: int = 20) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            resp = httpx.get(f"{base_url}/health", timeout=1)
            if resp.status_code == 200:
                return
        except httpx.HTTPError:
            pass
        time.sleep(0.5)
    raise TimeoutError(f"apfel server not ready at {base_url}")


def main():
    print(f"apfel server: {BASE}")
    print(f"Question:     {QUESTION}")
    print()

    wait_for_server(BASE)

    # Single request — apfel auto-executes MCP tools and returns the final answer
    resp = httpx.post(f"{API}/chat/completions", json={
        "model": "apple-foundationmodel",
        "messages": [{"role": "user", "content": QUESTION}],
    }, timeout=TIMEOUT)
    resp.raise_for_status()
    data = resp.json()

    choice = data["choices"][0]
    finish = choice["finish_reason"]
    answer = choice["message"].get("content", "")

    print(f"finish_reason: {finish}")
    print(f"Answer: {answer}")
    print()

    if '"tool_calls"' in answer:
        print("FAIL: answer is a raw tool_calls blob - tool was not executed.")
        sys.exit(1)

    if not answer.strip():
        print("FAIL: empty answer.")
        sys.exit(1)

    if not re.search(r"\d", answer):
        print("WARNING: answer contains no digits - tool may not have executed.")
        sys.exit(1)

    print("Round trip complete.")


if __name__ == "__main__":
    main()
