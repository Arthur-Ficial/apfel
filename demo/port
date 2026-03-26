#!/bin/bash
# port — what's using this port?, powered by Apple Intelligence
#
# Usage:  port 3000
#         port 8080
#         port 5432 -c    # copy to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

COPY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--copy) COPY=true; shift ;;
        -h|--help)
            echo "port — what's using this port?"
            echo ""
            echo "Usage: port [OPTIONS] <port-number>"
            echo ""
            echo "  -c, --copy  Copy explanation to clipboard"
            echo "  -h, --help  Show this help"
            echo ""
            echo "Examples:"
            echo "  port 3000"
            echo "  port 8080"
            echo "  port 5432"
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  PORT="$1"; shift ;;
    esac
done

if [[ -z "$PORT" ]]; then
    echo "Usage: port <port-number>"
    echo "       port --help for more options"
    exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: '$PORT' is not a valid port number" >&2
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

# Gather port info
info=$(lsof -i :"$PORT" -P -n 2>/dev/null)

if [[ -z "$info" ]]; then
    echo "Nothing is using port $PORT."
    exit 0
fi

SYSTEM="Explain in 1-2 sentences what process is using this port. Mention the process name, PID, and what the process likely is (e.g., 'Node.js dev server', 'PostgreSQL database', 'nginx web server'). If multiple processes, mention all. Be specific."

result=$(echo "Port $PORT:
$info" | apfel -q -s "$SYSTEM")
status=$?

if [[ $status -ne 0 ]]; then
    echo "Error: apfel failed (exit $status)" >&2
    # Fallback: just show raw lsof output
    echo "$info"
    exit $status
fi

if $COPY; then
    echo "$result" | pbcopy
    echo -e "\033[90m(copied to clipboard)\033[0m"
fi

echo "$result"
