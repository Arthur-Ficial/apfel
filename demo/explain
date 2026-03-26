#!/bin/bash
# explain — explain a command, error, or code snippet, powered by Apple Intelligence
#
# Usage:  explain "awk -F: '{print \$1,\$3}' /etc/passwd | sort -t' ' -k2 -n"
#         pbpaste | explain          # explain clipboard contents
#         echo "error: ..." | explain
#         explain -c "xargs -I{}"   # copy explanation to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

COPY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--copy) COPY=true; shift ;;
        -h|--help)
            echo "explain — explain a command, error, or code snippet"
            echo ""
            echo "Usage: explain [OPTIONS] \"snippet\""
            echo "       command 2>&1 | explain"
            echo "       pbpaste | explain"
            echo ""
            echo "  -c, --copy  Copy explanation to clipboard"
            echo "  -h, --help  Show this help"
            echo ""
            echo "Examples:"
            echo "  explain \"awk -F: '{print \\\$1}' /etc/passwd\""
            echo "  explain \"error: use of undeclared identifier 'x'\""
            echo "  explain \"curl -sSL -o /dev/null -w '%{http_code}'\""
            echo "  pbpaste | explain"
            echo "  dmesg | tail -5 | explain"
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  break ;;
    esac
done

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

# Get input from argument or stdin
if [[ -n "$1" ]]; then
    input="$1"
elif [[ ! -t 0 ]]; then
    input=$(cat)
else
    echo "Usage: explain \"command or error message\""
    echo "       some-command | explain"
    echo "       explain --help for more options"
    exit 1
fi

# Truncate if too long (keep within context window)
input=$(echo "$input" | head -30)

SYSTEM="Explain what this command, error, or code snippet does in 2-3 sentences. Be specific about each part. If it's an error, explain what caused it and how to fix it. No code fences, no bullet points — just plain sentences."

result=$(echo "$input" | apfel -q -s "$SYSTEM")
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
