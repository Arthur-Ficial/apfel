#!/bin/bash
# Run apfel integration tests against a live server.
# Requires: pip install openai pytest httpx
# Requires: Apple Intelligence enabled on this Mac.
set -e

echo "Building apfel (release)..."
swift build -c release 2>&1 | tail -1

echo "Starting server on port 11434..."
.build/release/apfel --serve --port 11434 &
SERVER_PID=$!

# Wait for server to be ready
for i in {1..10}; do
    if curl -s http://localhost:11434/health > /dev/null 2>&1; then
        echo "Server ready."
        break
    fi
    sleep 1
done

echo "Running tests..."
python3 -m pytest Tests/integration/openai_client_test.py -v
TEST_EXIT=$?

echo "Stopping server..."
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

exit $TEST_EXIT
