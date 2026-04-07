#!/bin/bash
# Run apfel integration tests against live servers.
# Requires: pip install openai pytest httpx
# Requires: Apple Intelligence enabled on this Mac.
set -e

# ── Port collision check ──
check_port() {
    if lsof -iTCP:"$1" -sTCP:LISTEN -P -n 2>/dev/null | grep -q LISTEN; then
        local pid=$(lsof -iTCP:"$1" -sTCP:LISTEN -P -n -t 2>/dev/null | head -1)
        local cmd=$(ps -p "$pid" -o comm= 2>/dev/null)
        echo "ERROR: Port $1 is in use by PID $pid ($cmd)."
        echo "Fix: kill $pid  or  apfel --serve --port <other-port>"
        return 1
    fi
    return 0
}

# Kill any leftover apfel servers from previous runs
pkill -f "apfel --serve" 2>/dev/null || true
sleep 1

# Verify ports are free BEFORE starting servers
if ! check_port 11434 || ! check_port 11435; then
    echo ""
    echo "Ports still occupied after cleanup. Waiting 3s and retrying..."
    sleep 3
    if ! check_port 11434 || ! check_port 11435; then
        echo "FATAL: Cannot free ports 11434/11435. Aborting."
        exit 1
    fi
fi

# ── Cleanup trap: ALWAYS kill servers on exit ──
SERVER_PID=""
MCP_SERVER_PID=""
cleanup() {
    echo "Stopping servers..."
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
    [ -n "$MCP_SERVER_PID" ] && kill "$MCP_SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" "$MCP_SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── Build ──
echo "Building apfel (release)..."
swift build -c release 2>&1 | tail -1

# ── Start servers ──
echo "Starting server on port 11434..."
.build/release/apfel --serve --port 11434 2>/dev/null &
SERVER_PID=$!

echo "Starting MCP server on port 11435..."
.build/release/apfel --serve --port 11435 --mcp mcp/calculator/server.py 2>/dev/null &
MCP_SERVER_PID=$!

# Wait for both servers (timeout 15s)
READY=0
for i in {1..15}; do
    if curl -sf http://localhost:11434/health > /dev/null 2>&1 && \
       curl -sf http://localhost:11435/health > /dev/null 2>&1; then
        echo "Both servers ready (${i}s)."
        READY=1
        break
    fi
    sleep 1
done
if [ "$READY" -ne 1 ]; then
    echo "FATAL: Servers failed to start within 15 seconds."
    echo "Server PID: $SERVER_PID (alive: $(kill -0 $SERVER_PID 2>/dev/null && echo yes || echo NO))"
    echo "MCP PID: $MCP_SERVER_PID (alive: $(kill -0 $MCP_SERVER_PID 2>/dev/null && echo yes || echo NO))"
    exit 1
fi

# ── Run tests ──
# Order: CLI first (no server), then server tests (11434), then MCP tests (11435 last)
echo "Running tests..."
python3 -m pytest \
    Tests/integration/cli_e2e_test.py \
    Tests/integration/service_test.py \
    Tests/integration/performance_test.py \
    Tests/integration/openai_client_test.py \
    Tests/integration/openapi_spec_test.py \
    Tests/integration/security_test.py \
    Tests/integration/mcp_server_test.py \
    -v --tb=short -x
