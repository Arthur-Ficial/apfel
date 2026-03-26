#!/bin/bash
# naming — name things well, powered by Apple Intelligence
#
# Usage:  naming "function that retries HTTP requests with backoff"
#         naming "variable for the number of failed logins"
#         naming -c "config file for database migrations"   # copy to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

COPY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--copy) COPY=true; shift ;;
        -h|--help)
            echo "naming — name things well"
            echo ""
            echo "Usage: naming [OPTIONS] \"what it does\""
            echo ""
            echo "  -c, --copy  Copy suggestions to clipboard"
            echo "  -h, --help  Show this help"
            echo ""
            echo "Examples:"
            echo "  naming \"function that retries HTTP requests with backoff\""
            echo "  naming \"variable for the count of failed login attempts\""
            echo "  naming \"class that manages WebSocket connections\""
            echo "  naming \"file containing database migration scripts\""
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  break ;;
    esac
done

if [[ -z "$1" ]]; then
    echo "Usage: naming \"describe what it does\""
    echo "       naming --help for more options"
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

SYSTEM="Suggest 5 names for what the user describes. Show each on its own line in this format:
camelCase | snake_case | short explanation (max 5 words)

No numbering, no bullet points, no other text. Just 5 lines of suggestions."

result=$(apfel -q -s "$SYSTEM" "$1")
status=$?

if [[ $status -ne 0 ]]; then
    echo "Error: apfel failed (exit $status)" >&2
    exit $status
fi

if $COPY; then
    echo "$result" | pbcopy
    echo -e "\033[90m(copied to clipboard)\033[0m"
fi

echo "$result"
