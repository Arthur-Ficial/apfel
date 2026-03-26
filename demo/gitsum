#!/bin/bash
# gitsum — summarize recent git activity, powered by Apple Intelligence
#
# Usage:  gitsum          # last 10 commits
#         gitsum 20       # last 20 commits
#         gitsum -c       # copy summary to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

COPY=false
COUNT=10

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--copy) COPY=true; shift ;;
        -h|--help)
            echo "gitsum — summarize recent git activity"
            echo ""
            echo "Usage: gitsum [OPTIONS] [count]"
            echo ""
            echo "  count        Number of commits to summarize (default: 10)"
            echo "  -c, --copy   Copy summary to clipboard"
            echo "  -h, --help   Show this help"
            echo ""
            echo "Examples:"
            echo "  gitsum        # last 10 commits"
            echo "  gitsum 20     # last 20 commits"
            echo "  gitsum -c 5   # last 5, copy to clipboard"
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                COUNT="$1"
            else
                echo "Error: '$1' is not a number. Use --help." >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Check we're in a git repo
if ! git rev-parse --git-dir &>/dev/null 2>&1; then
    echo "Error: not a git repository" >&2
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

# Gather git log (compact, fits in context window)
log=$(git log --oneline -"$COUNT" 2>/dev/null)
branch=$(git branch --show-current 2>/dev/null)
authors=$(git log --format='%an' -"$COUNT" 2>/dev/null | sort | uniq -c | sort -rn | head -5)

if [[ -z "$log" ]]; then
    echo "No commits found."
    exit 0
fi

SYSTEM="Summarize this git log in 2-4 sentences. Group related changes (features, fixes, refactors, docs). Mention what was built or changed, not individual commit hashes. Be specific about what happened. No bullet points."

result=$(echo "Branch: $branch
Recent $COUNT commits:
$log

Authors:
$authors" | apfel -q -s "$SYSTEM")
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
