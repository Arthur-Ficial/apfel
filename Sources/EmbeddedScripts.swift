// ============================================================================
// EmbeddedScripts.swift — Embedded developer tool scripts for apfel
// Completely self-contained scripts compiled directly into the binary.
// ============================================================================

import Foundation

struct EmbeddedScripts {
    static let scripts: [String: String] = [
        "cmd": #"""
#!/bin/bash
# cmd — natural language to shell command, powered by Apple Intelligence
# Install globally as `apfel-cmd`: see demo/README.md "Install demos globally (optional)"
#
# Usage:  cmd "find files larger than 100MB"
#         cmd -x "list all open ports"       # execute (asks confirm)
#         cmd -c "show disk usage sorted by size"   # copy to clipboard
#
# Shell function version (add to .zshrc):
#   cmd(){ local x c r a; while [[ $1 == -* ]]; do case $1 in -x)x=1;shift;; -c)c=1;shift;; *)break;; esac; done; r=$(apfel -q -s 'Output only a shell command.' "$*" | sed '/^```/d;/^#/d;s/\x1b\[[0-9;]*[a-zA-Z]//g;s/^[[:space:]]*//;/^$/d' | head -1); [[ $r ]] || { echo "no command generated"; return 1; }; printf '\e[32m$\e[0m %s\n' "$r"; [[ $c ]] && printf %s "$r" | pbcopy && echo "(copied)"; [[ $x ]] && { printf 'Run? [y/N] '; read -r a; [[ $a == y ]] && eval "$r"; }; return 0; }
#
# Examples:
#   cmd find all swift files larger than 1MB
#   cmd -c show disk usage sorted by size
#   cmd -x what process is using port 3000
#   cmd list all git branches merged into main
#
# Note: Apple's on-device model has safety guardrails that may block prompts
# containing words like "kill", "terminate", "destroy", etc. — even in
# legitimate contexts (e.g. "kill all node processes"). Rephrase to avoid:
#   BAD:  cmd "kill all node processes"
#   GOOD: cmd "stop all running node processes"
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

EXECUTE=false
COPY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -x|--execute)  EXECUTE=true; shift ;;
        -c|--copy)     COPY=true; shift ;;
        -h|--help)
            echo "cmd — natural language to shell command"
            echo ""
            echo "Usage: cmd [OPTIONS] \"description\""
            echo ""
            echo "  -x, --execute  Run the command (asks confirmation first)"
            echo "  -c, --copy     Copy command to clipboard"
            echo "  -h, --help     Show this help"
            echo ""
            echo "Examples:"
            echo "  cmd \"find all .log files modified today\""
            echo "  cmd -x \"show disk usage sorted by size\""
            echo "  cmd -c \"awk to sum column 3 of a CSV\""
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  break ;;
    esac
done

if [[ -z "$1" ]]; then
    echo "Usage: cmd \"what you want to do\""
    echo "       cmd --help for more options"
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

SYSTEM="You are a shell command generator for macOS (zsh/bash). Output ONLY the command — no explanation, no markdown, no code fences, no comments. If multiple commands are needed, join them with && or |. Never output anything except the command itself."

result=$(apfel -q -s "$SYSTEM" "$1")
status=$?

if [[ $status -ne 0 ]]; then
    echo "Error: apfel failed (exit $status)" >&2
    exit $status
fi

# Strip markdown fences, ANSI escape sequences, and whitespace
result=$(echo "$result" | sed '/^```/d' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | sed 's/^[[:space:]]*//' | sed '/^$/d')

if $COPY; then
    echo "$result" | pbcopy
    echo -e "\033[90m(copied to clipboard)\033[0m"
fi

echo -e "\033[32m\$\033[0m $result"

if $EXECUTE; then
    echo ""
    read -r -p "Run this? [y/N] " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        eval "$result"
    fi
fi
"""#,

        "oneliner": #"""
#!/bin/bash
# oneliner — complex pipe chains from plain English, powered by Apple Intelligence
# Install globally as `apfel-oneliner`: see demo/README.md "Install demos globally (optional)"
#
# Usage:  oneliner "sum the third column of a CSV"
#         oneliner -x "count unique IPs in access.log"    # execute (asks confirm)
#         oneliner -c "remove duplicate lines"            # copy to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

EXECUTE=false
COPY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -x|--execute)  EXECUTE=true; shift ;;
        -c|--copy)     COPY=true; shift ;;
        -h|--help)
            echo "oneliner — complex pipe chains from plain English"
            echo ""
            echo "Usage: oneliner [OPTIONS] \"description\""
            echo ""
            echo "  -x, --execute  Run the command (asks confirmation first)"
            echo "  -c, --copy     Copy command to clipboard"
            echo "  -h, --help     Show this help"
            echo ""
            echo "Examples:"
            echo "  oneliner \"sum the third column of a CSV\""
            echo "  oneliner -x \"count unique IPs in access.log\""
            echo "  oneliner -c \"extract all URLs from a file\""
            echo ""
            echo "Specializes in: awk, sed, find, xargs, sort, uniq,"
            echo "grep, cut, tr, jq, and complex pipe chains."
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  break ;;
    esac
done

if [[ -z "$1" ]]; then
    echo "Usage: oneliner \"what you need\""
    echo "       oneliner --help for more options"
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

SYSTEM="You generate UNIX one-liners for macOS (zsh/bash). Output ONLY the command — no explanation, no markdown, no code fences. Prefer awk, sed, grep, sort, uniq, cut, tr, xargs, find, and jq. Use pipes. Keep it to a single line. Never output anything except the command."

result=$(apfel -q -s "$SYSTEM" "$1")
status=$?

if [[ $status -ne 0 ]]; then
    echo "Error: apfel failed (exit $status)" >&2
    exit $status
fi

# Strip any accidental markdown fences the model might add
# Strip markdown fences, ANSI escape sequences, and whitespace
result=$(echo "$result" | sed '/^```/d' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | sed 's/^[[:space:]]*//' | sed '/^$/d')

if $COPY; then
    echo "$result" | pbcopy
    echo -e "\033[90m(copied to clipboard)\033[0m"
fi

echo -e "\033[33m\$\033[0m $result"

if $EXECUTE; then
    echo ""
    read -r -p "Run this? [y/N] " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        eval "$result"
    fi
fi
"""#,

        "naming": #"""
#!/bin/bash
# naming — name things well, powered by Apple Intelligence
# Install globally as `apfel-naming`: see demo/README.md "Install demos globally (optional)"
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
"""#,

        "explain": #"""
#!/bin/bash
# explain — explain a command, error, or code snippet, powered by Apple Intelligence
# Install globally as `apfel-explain`: see demo/README.md "Install demos globally (optional)"
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
"""#,

        "wtd": #"""
#!/bin/bash
# wtd — what is this directory?, powered by Apple Intelligence
# Install globally as `apfel-wtd`: see demo/README.md "Install demos globally (optional)"
#
# Usage:  wtd              # current directory
#         wtd ~/projects   # any directory
#         wtd -c           # copy summary to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

COPY=false
TARGET="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--copy) COPY=true; shift ;;
        -h|--help)
            echo "wtd — what is this directory?"
            echo ""
            echo "Usage: wtd [OPTIONS] [directory]"
            echo ""
            echo "  -c, --copy  Copy summary to clipboard"
            echo "  -h, --help  Show this help"
            echo ""
            echo "Examples:"
            echo "  wtd                     # current directory"
            echo "  wtd ~/some/project      # any directory"
            echo "  wtd -c .                # copy summary to clipboard"
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  TARGET="$1"; shift ;;
    esac
done

if [[ ! -d "$TARGET" ]]; then
    echo "Error: '$TARGET' is not a directory" >&2
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

# Gather directory info (kept small for context window)
snapshot=""

# File listing
snapshot+="Directory: $(cd "$TARGET" && pwd)
"
snapshot+="$(ls -la "$TARGET" 2>/dev/null | head -30)
"

# Check for key project files and grab first few lines
for f in README.md README readme.md Package.swift package.json Cargo.toml go.mod pyproject.toml Makefile Dockerfile docker-compose.yml .gitignore; do
    if [[ -f "$TARGET/$f" ]]; then
        snippet=$(head -5 "$TARGET/$f" 2>/dev/null)
        snapshot+="
--- $f (first 5 lines) ---
$snippet
"
    fi
done

# Git info if available
if [[ -d "$TARGET/.git" ]] || git -C "$TARGET" rev-parse --git-dir &>/dev/null 2>&1; then
    branch=$(git -C "$TARGET" branch --show-current 2>/dev/null)
    last_commit=$(git -C "$TARGET" log --oneline -1 2>/dev/null)
    snapshot+="
--- git ---
branch: $branch
last commit: $last_commit
"
fi

SYSTEM="Summarize what this directory/project is in 2-3 sentences. Mention: what language/framework, what it does, how to build/run it if obvious. Be concise and specific. No bullet points."

result=$(echo "$snapshot" | apfel -q -s "$SYSTEM")
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
"""#,

        "port": #"""
#!/bin/bash
# port — what's using this port?, powered by Apple Intelligence
# Install globally as `apfel-port`: see demo/README.md "Install demos globally (optional)"
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
"""#,

        "process": #"""
#!/bin/bash
# process — what's this process about?, powered by Apple Intelligence
# Install globally as `apfel-process`: see demo/README.md "Install demos globally (optional)"
#
# Usage:  process <PID>
#         process 1234 -c    # copy explanation to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

COPY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--copy) COPY=true; shift ;;
        -h|--help)
            echo "process — what's this process about?"
            echo ""
            echo "Usage: process [OPTIONS] <PID>"
            echo ""
            echo "  -c, --copy  Copy explanation to clipboard"
            echo "  -h, --help  Show this help"
            echo ""
            echo "Examples:"
            echo "  process 648"
            echo "  process 1234 -c"
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  PID="$1"; shift ;;
    esac
done

if [[ -z "$PID" ]]; then
    echo "Usage: process <PID>"
    echo "       process --help for more options"
    exit 1
fi

if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
    echo "Error: '$PID' is not a valid Process ID (PID)" >&2
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

# Gather process info from ps
ps_info=$(ps -p "$PID" -o pid,ppid,user,%cpu,%mem,command 2>/dev/null)

if [[ -z "$ps_info" ]]; then
    echo "Process $PID is not running."
    exit 0
fi

# Gather open files and network descriptors (kept concise)
open_files=$(lsof -p "$PID" -P -n 2>/dev/null | head -15)
network_info=$(lsof -a -p "$PID" -i -P -n 2>/dev/null)

snapshot="PID Info:
$ps_info"

if [[ -n "$network_info" ]]; then
    snapshot+="

Network Connections:
$network_info"
fi

if [[ -n "$open_files" ]]; then
    snapshot+="

Open Files Snippet:
$open_files"
fi

SYSTEM="Explain in 1-2 sentences what this running process is. Mention the process name, PID, user, and what the process likely does. If it's a daemon, web server, development command, or browser worker, say so specifically. Keep it concise."

result=$(echo "$snapshot" | apfel -q -s "$SYSTEM")
status=$?

if [[ $status -ne 0 ]]; then
    echo "Error: apfel failed (exit $status)" >&2
    # Fallback
    echo "$ps_info"
    exit $status
fi

if $COPY; then
    echo "$result" | pbcopy
    echo -e "\033[90m(copied to clipboard)\033[0m"
fi

echo "$result"
"""#,

        "daemon": #"""
#!/bin/bash
# daemon — what's this macOS daemon/command about?, powered by Apple Intelligence
# Install globally as `apfel-daemon`: see demo/README.md "Install demos globally (optional)"
#
# Usage:  daemon <name>
#         daemon mDNSResponder -c    # copy explanation to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

COPY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--copy) COPY=true; shift ;;
        -h|--help)
            echo "daemon — what's this macOS daemon/command about?"
            echo ""
            echo "Usage: daemon [OPTIONS] <daemon-or-command-name>"
            echo ""
            echo "  -c, --copy  Copy explanation to clipboard"
            echo "  -h, --help  Show this help"
            echo ""
            echo "Examples:"
            echo "  daemon mDNSResponder"
            echo "  daemon configd -c"
            echo "  daemon xpcproxy"
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  QUERY="$1"; shift ;;
    esac
done

if [[ -z "$QUERY" ]]; then
    echo "Usage: daemon <daemon-or-command-name>"
    echo "       daemon --help for more options"
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

echo -e "\033[90mSearching system for context on '$QUERY'...\033[0m"

# 1. Locate the binary path
binary_path=""
for dir in /usr/libexec /usr/sbin /usr/bin /sbin /bin /System/Library/CoreServices; do
    if [[ -x "$dir/$QUERY" ]]; then
        binary_path="$dir/$QUERY"
        break
    fi
done

if [[ -z "$binary_path" ]]; then
    # Try which / whereis
    binary_path=$(which "$QUERY" 2>/dev/null)
fi

# 2. Check launchd plist
plist_info=""
plist_file=$(find /System/Library/LaunchDaemons /System/Library/LaunchAgents /Library/LaunchDaemons /Library/LaunchAgents -name "*$QUERY*" 2>/dev/null | head -1)
if [[ -n "$plist_file" ]]; then
    plist_info="Launchd Config Path: $plist_file"
    if command -v plutil &>/dev/null; then
        program_args=$(plutil -extract ProgramArguments xml1 -o - "$plist_file" 2>/dev/null | grep -A 5 "<array>" | tr -d '\n' | sed 's/<[^>]*>//g' | xargs)
        [[ -n "$program_args" ]] && plist_info+="\nProgram Arguments: $program_args"
    fi
fi

# 3. Check if currently running
running_processes=$(ps -ax -o pid,user,command | grep -i "$QUERY" | grep -v grep | head -3)

snapshot="Daemon/Command Query: $QUERY"
if [[ -n "$binary_path" ]]; then
    snapshot+="
Binary Path: $binary_path"
fi
if [[ -n "$plist_info" ]]; then
    snapshot+="
$plist_info"
fi
if [[ -n "$running_processes" ]]; then
    snapshot+="
Currently Running Instances:
$running_processes"
fi

SYSTEM="You are a macOS systems architecture expert. Explain what the requested macOS daemon, system service, or command does and how it internally works. 
In 2-3 sentences, detail:
1. What components it manages or interacts with.
2. Its role within macOS (e.g., networking, IPC, security, background services).
3. Any interesting internal details or architectural context.
Keep the tone highly professional, precise, and educational. Avoid generic summaries; be technically specific."

result=$(echo "$snapshot" | apfel -q -s "$SYSTEM")
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
"""#,

        "docs-apple": #"""
#!/bin/bash
# docs-apple — smart developer documentation & code helper, powered by Apple Intelligence
# Install globally as `apfel-docs-apple`: see demo/README.md "Install demos globally (optional)"
#
# Usage:  docs-apple SwiftUI Button
#         docs-apple Task
#         docs-apple Combine Publisher -c    # copy to clipboard
#
# Requires: apfel installed (https://github.com/Arthur-Ficial/apfel)

COPY=false
NO_SOSUMI=false
DOC_TOKEN_BUDGET=2000
CANDIDATE_FRAMEWORKS=(
    "accelerate" "accessibility" "accounts" "adservices" "appattest" "appclips" "appintents"
    "appkit" "appstoreconnect" "appstoreserverapi" "arkit" "audiotoolbox" "audiounit"
    "avfaudio" "avfoundation" "avkit" "backgroundassets" "backgroundtasks" "browserenginekit"
    "callkit" "carplay" "classkit" "cloudkit" "cloudkitjs" "combine" "compression" "contacts"
    "contactsui" "contacts" "coreaudiokit" "coreaudio" "corebluetooth" "coredata" "corefoundation"
    "coregraphics" "corehaptics" "coreimage" "corelocation" "coremedia" "coremediaio"
    "coremotion" "coreservices" "corespotlight" "coretelephony" "coretext" "coretransferable"
    "corevideo" "cryptokit" "deviceactivity" "devicemanagement" "devicediscovery"
    "eventkit" "eventkitui" "executionpolicy" "exposurenotification" "externalaccessory"
    "familycontrols" "fileprovider" "financekit" "foundationmodels" "foundation" "gamecontroller"
    "gamekit" "gameplaykit" "groupactivities" "healthkitui" "healthkit" "homekit" "hypervisor"
    "identitylookup" "imagecapturecore" "imageio" "inputmethodkit" "iosurface" "javascriptcore"
    "localauthentication" "managedsettings" "mapkit" "matter" "mediaplayer" "metalperformanceshaders"
    "metalkit" "metal" "metrickit" "modelio" "multipeerconnectivity" "musickit"
    "nearbyinteraction" "networkextension" "network" "notificationcenter" "oslog" "passkit"
    "pencilkit" "phase" "photosui" "photos" "quicklookthumbnailing" "quicklook" "realitykit"
    "replaykit" "roomplan" "safariservices" "scenekit" "screencapturekit" "screensaver"
    "security" "sensorkit" "servicemanagement" "shazamkit" "social" "soundanalysis"
    "speech" "spritekit" "storekit" "swiftcharts" "swiftdata" "swiftui" "swift" "symbolkit"
    "systemconfiguration" "system" "tabulardata" "tipkit" "tvmlkit" "uikit" "usernotificationsui"
    "usernotifications" "videosubscriberaccount" "visionkit" "vision" "watchconnectivity"
    "watchkit" "webkit" "widgetkit" "xctest"
)
INTENT_WORDS=("explain" "what" "how" "why" "show" "tell" "overview" "summarize" "summary" "describe")
DOC_QUERY_STOP_WORDS=(
    "a" "an" "the" "in" "of" "for" "to" "me" "about" "few" "sentences" "sentence"
    "no" "code" "samples" "sample" "please" "briefly" "short" "shortly" "with" "without"
)

# Common developer symbols to automatically detect and ground natural language queries with
COMMON_SYMBOLS=(
    "App" "Scene" "WindowGroup" "DocumentGroup" "Settings" "Commands" "View" "Text" "Label"
    "Button" "Menu" "Picker" "Toggle" "Slider" "Stepper" "TextField" "SecureField" "TextEditor"
    "Searchable" "Form" "List" "Table" "Grid" "LazyVGrid" "LazyHGrid" "Section" "Group" "DisclosureGroup"
    "NavigationStack" "NavigationSplitView" "NavigationLink" "TabView" "ToolbarItem" "ToolbarItemGroup"
    "ScrollView" "ScrollViewReader" "LazyVStack" "LazyHStack" "VStack" "HStack" "ZStack" "Spacer" "Divider"
    "Image" "AsyncImage" "Color" "Gradient" "LinearGradient" "RadialGradient" "AngularGradient" "Shape"
    "Circle" "Rectangle" "RoundedRectangle" "Capsule" "Path" "Font" "Animation" "Transition" "GeometryReader"
    "ViewModifier" "Environment" "EnvironmentObject" "EnvironmentValues" "State" "StateObject" "Binding"
    "Bindable" "ObservedObject" "Observable" "ObservableObject" "Published" "FocusState" "GestureState"
    "Namespace" "PreferenceKey" "Layout" "SceneStorage" "AppStorage" "FetchRequest" "Query"

    "Task" "TaskGroup" "ThrowingTaskGroup" "MainActor" "Actor" "Sendable" "AsyncSequence"
    "AsyncStream" "AsyncThrowingStream" "Continuation" "TaskLocal" "Clock" "Duration" "Instant"

    "String" "Substring" "Array" "Dictionary" "Set" "Optional" "Result" "Range" "ClosedRange"
    "Sequence" "Collection" "RandomAccessCollection" "IteratorProtocol" "Codable" "Encodable" "Decodable"
    "Identifiable" "Hashable" "Equatable" "Comparable" "Error" "LocalizedError" "Date" "Data" "URL"
    "URLRequest" "URLComponents" "URLSession" "URLSessionConfiguration" "URLSessionTask" "URLSessionDataTask"
    "URLSessionUploadTask" "URLSessionDownloadTask" "JSONDecoder" "JSONEncoder" "PropertyListDecoder"
    "PropertyListEncoder" "FileManager" "Bundle" "ProcessInfo" "NotificationCenter" "Notification" "Timer"
    "Calendar" "Locale" "TimeZone" "Measurement" "Formatter" "DateFormatter" "NumberFormatter" "UUID"
    "IndexSet" "Operation" "OperationQueue" "UserDefaults" "NSError" "NSPredicate" "NSSortDescriptor"

    "Model" "ModelContext" "ModelContainer" "ModelConfiguration" "Query" "FetchDescriptor" "SortDescriptor"
    "Predicate" "Relationship" "Attribute" "Transient" "PersistentModel" "PersistentIdentifier"

    "Publisher" "Subscriber" "Subscription" "Subject" "PassthroughSubject" "CurrentValueSubject" "AnyPublisher"
    "AnyCancellable" "Cancellable" "Future" "Just" "Empty" "Fail" "Published" "ObservableObjectPublisher"

    "UIApplication" "UIScene" "UIWindow" "UIView" "UIViewController" "UILabel" "UIButton" "UIImage"
    "UIImageView" "UITableView" "UICollectionView" "UINavigationController" "UITabBarController"
    "UIAlertController" "UIStackView" "UIColor" "UIFont" "UIScreen" "UIResponder" "UIControl" "UIAction"
    "NSApplication" "NSWindow" "NSView" "NSViewController" "NSButton" "NSTextField" "NSTableView"
    "NSCollectionView" "NSImage" "NSColor" "NSFont" "NSMenu" "NSMenuItem" "NSResponder"

    "CGColor" "CGRect" "CGSize" "CGPoint" "CGPath" "CGImage" "CGContext" "CGAffineTransform"
    "CIImage" "CIFilter" "CIContext" "CVPixelBuffer" "AVPlayer" "AVAsset" "AVAudioEngine" "AVAudioSession"
    "AVCaptureSession" "AVCaptureDevice" "AVCapturePhotoOutput" "PHAsset" "PHPhotoLibrary"

    "CLLocation" "CLLocationManager" "CLLocationCoordinate2D" "MKMapView" "MKMapItem" "MKCoordinateRegion"
    "MKAnnotation" "MKPointAnnotation" "MKRoute" "HKHealthStore" "HKSample" "HKQuantity" "HKWorkout"
    "INIntent" "AppIntent" "IntentResult" "EntityQuery" "AppEntity" "Transferable" "FileDocument"
    "UNUserNotificationCenter" "UNNotificationRequest" "UNMutableNotificationContent" "Widget" "TimelineProvider"
    "TimelineEntry" "WidgetConfiguration" "Tip" "StoreView" "ProductView" "SubscriptionStoreView" "Product"
    "Transaction" "SKProduct" "SKPaymentQueue" "LAContext" "SecKey" "Keychain" "URLCredential"
    "NWConnection" "NWListener" "NWEndpoint" "NEVPNManager" "CKContainer" "CKDatabase" "CKRecord"
    "CKQuery" "CKShare" "CBPeripheral" "CBCentralManager" "ARSession" "ARView" "RealityView"
    "Entity" "ModelEntity" "SCNScene" "SCNNode" "SKScene" "SKNode" "MTLDevice" "MTLCommandQueue"
    "MLModel" "VNRequest" "VNImageRequestHandler" "VNRecognizeTextRequest" "WKWebView" "WKNavigation"
    "XCTestCase" "XCTAssert" "Logger" "OSLog"
)


while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--copy) COPY=true; shift ;;
        --no-sosumi) NO_SOSUMI=true; shift ;;
        --[0-9]*) DOC_TOKEN_BUDGET="${1#--}"; shift ;;
        -h|--help)
            echo "docs-apple — smart developer documentation & code helper"
            echo ""
            echo "Usage: docs-apple [OPTIONS] [Framework] <Symbol-or-Task>"
            echo ""
            echo "  -c, --copy  Copy explanation & code to clipboard"
            echo "  --2000      Trim fetched docs to ~2000 tokens (default; use --3000, --1000, etc.)"
            echo "  --no-sosumi Force native curl/parser path even if sosumi is installed"
            echo "  -h, --help  Show this help"
            echo ""
            echo "Examples:"
            echo "  docs-apple SwiftUI Button"
            echo "  docs-apple Task"
            echo "  docs-apple Combine Publisher -c"
            echo ""
            echo "Requires: apfel (Apple Intelligence CLI)"
            exit 0
            ;;
        -*) echo "Unknown option: $1. Use --help."; exit 1 ;;
        *)  ARGS+=("$1"); shift ;;
    esac
done

# Split any ARGS elements that contain whitespace to support single-string query wrappers (e.g. from MCP or apfel router)
SPLIT_ARGS=()
for arg in "${ARGS[@]}"; do
    read -r -a words <<< "$arg"
    SPLIT_ARGS+=("${words[@]}")
done
ARGS=("${SPLIT_ARGS[@]}")

if [[ ${#ARGS[@]} -eq 0 ]]; then
    echo "Usage: docs-apple [Framework] <Symbol-or-Task>"
    echo "       docs-apple --help for more options"
    exit 1
fi

# Check apfel is installed
if ! command -v apfel &>/dev/null; then
    echo "Error: apfel not found. Install from https://github.com/Arthur-Ficial/apfel"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER_PATH="$SCRIPT_DIR/helpers/docs_apple_parser.py"
TRIM_CONTEXT_PATH="$SCRIPT_DIR/helpers/trim_context.py"

# --- Documentation helpers ---

has_sosumi() { [[ "$NO_SOSUMI" != "true" ]] && command -v sosumi &>/dev/null; }

trim_context() {
    if [[ -f "$TRIM_CONTEXT_PATH" ]]; then
        python3 "$TRIM_CONTEXT_PATH" --max-tokens "$DOC_TOKEN_BUDGET"
    else
        head -c "$((DOC_TOKEN_BUDGET * 4))"
    fi
}

# Fetch documentation for fw/symbol. Returns markdown on stdout, empty on failure.
fetch_docs() {
    local fw="$1" symbol="$2"
    local raw=""
    if has_sosumi; then
        if [[ -n "$symbol" ]]; then
            raw=$(sosumi fetch "${fw}/${symbol}" 2>/dev/null) || return 1
        else
            raw=$(sosumi fetch "$fw" 2>/dev/null) || return 1
        fi
    else
        local url
        if [[ -n "$symbol" ]]; then
            url="https://developer.apple.com/tutorials/data/documentation/${fw}/${symbol}.json"
        else
            url="https://developer.apple.com/tutorials/data/documentation/${fw}.json"
        fi
        local response
        response=$(curl -s -f --connect-timeout 10 --max-time 15 "$url" 2>/dev/null) || return 1
        if [[ -n "$response" && -f "$PARSER_PATH" ]]; then
            raw=$(echo "$response" | python3 "$PARSER_PATH" 2>/dev/null)
        fi
    fi
    [[ -n "$raw" ]] && echo "$raw" | trim_context
}

# Search Apple docs. Returns "fw/symbol" path on stdout, empty on failure.
search_docs() {
    local query="$1"
    if has_sosumi; then
        local result
        result=$(sosumi search "$query" --json 2>/dev/null) || return 1
        echo "$result" | python3 -c "
import sys, json
try:
    for r in json.load(sys.stdin).get('results',[]):
        u = r.get('url','')
        if '/documentation/' in u:
            p = u.split('/documentation/')
            if len(p) > 1: print(p[1]); break
except: pass
"
    else
        local ua="Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        local response
        response=$(curl -s --connect-timeout 10 --max-time 15 \
            -X POST "https://devintserv.msc.sbz.apple.com/api/v1/search" \
            -H "Origin: https://developer.apple.com" \
            -H "Referer: https://developer.apple.com/search/" \
            -H "Content-Type: application/json" \
            -H "User-Agent: $ua" \
            -d "{\"text\":\"$query\",\"targetResultLocale\":\"en\"}" 2>/dev/null) || return 1
        echo "$response" | python3 -c "
import sys, json
try:
    for r in json.load(sys.stdin).get('results',[]):
        u = r.get('url','')
        if '/documentation/' in u:
            p = u.split('/documentation/')
            if len(p) > 1: print(p[1]); break
except: pass
"
    fi
}

# Normalize inputs
FRAMEWORK=""
SYMBOL=""
RAW_QUERY="${ARGS[*]}"
IS_NATURAL_LANGUAGE=false
HAS_QUERY_INTENT=false

clean_token() {
    echo "$1" | tr -d "\"'\`.,?!()[]{}:" | tr '[:upper:]' '[:lower:]'
}

build_symbol_path() {
    local parts=()
    for word in "$@"; do
        token=$(clean_token "$word")
        [[ -n "$token" ]] && parts+=("$token")
    done
    local joined="${parts[*]}"
    echo "${joined// //\/}"
}

extract_explicit_tags() {
    EXPLICIT_TAGS=()
    for word in "${ARGS[@]}"; do
        if [[ "$word" =~ ^@(.+) ]]; then
            EXPLICIT_TAGS+=("${BASH_REMATCH[1]}")
        fi
    done
    [[ ${#EXPLICIT_TAGS[@]} -gt 0 ]]
}

build_probable_doc_query() {
    # Priority 1: explicit @keyword tags from the user.
    if [[ ${#EXPLICIT_TAGS[@]} -gt 0 ]]; then
        echo -e "\033[90mExplicit @keyword tags detected: ${EXPLICIT_TAGS[*]}\033[0m"
        echo "${EXPLICIT_TAGS[*]}"
        return
    fi

    local symbol_hint=""
    if [[ -n "$EXTRACTED_SYMBOL" ]]; then
        symbol_hint="$EXTRACTED_SYMBOL"
    elif [[ -n "$SYMBOL" && "$SYMBOL" != "$FRAMEWORK" ]]; then
        symbol_hint="$SYMBOL"
    fi

    if [[ -n "$FRAMEWORK" && -n "$symbol_hint" ]]; then
        echo "$FRAMEWORK $symbol_hint"
    elif [[ -n "$symbol_hint" ]]; then
        echo "$symbol_hint"
    elif [[ -n "$FRAMEWORK" ]]; then
        echo "$FRAMEWORK"
    else
        local terms=()
        for word in "${ARGS[@]}"; do
            token=$(clean_token "$word")
            [[ -z "$token" ]] && continue
            skip=false
            for intent in "${INTENT_WORDS[@]}"; do
                if [[ "$token" == "$intent" ]]; then skip=true; break; fi
            done
            if ! $skip; then
                for stop in "${DOC_QUERY_STOP_WORDS[@]}"; do
                    if [[ "$token" == "$stop" ]]; then skip=true; break; fi
                done
            fi
            ! $skip && terms+=("$word")
        done
        if [[ ${#terms[@]} -gt 0 ]]; then
            echo "${terms[*]}"
        else
            echo "$RAW_QUERY"
        fi
    fi
}

search_and_fetch_docs() {
    local query="$1"
    [[ -z "$query" ]] && return 1

    echo -e "\033[90mSearching Apple docs for '$query'...\033[0m"
    local search_path
    search_path=$(search_docs "$query")
    [[ -z "$search_path" ]] && return 1

    local fw sym
    if [[ "$search_path" == */* ]]; then
        fw="${search_path%%/*}"
        sym="${search_path#*/}"
    else
        fw="$search_path"
        sym=""
    fi

    [[ -z "$fw" ]] && return 1
    doc_context=$(fetch_docs "$fw" "$sym")
    if [[ -n "$doc_context" ]]; then
        FRAMEWORK="$fw"
        SYMBOL="$sym"
        return 0
    fi
    return 1
}

for word in "${ARGS[@]}"; do
    word_lower=$(clean_token "$word")
    for intent in "${INTENT_WORDS[@]}"; do
        if [[ "$word_lower" == "$intent" ]]; then
            HAS_QUERY_INTENT=true
            break 2
        fi
    done
done

# Scan ALL words for a framework name — not just the first word.
# "explain in few sentences Combine framework" → finds Combine at position 4.
FW_INDEX=-1
for i in "${!ARGS[@]}"; do
    word_lower=$(clean_token "${ARGS[$i]}")
    for fw in "${CANDIDATE_FRAMEWORKS[@]}"; do
        if [[ "$word_lower" == "$fw" ]]; then
            FRAMEWORK="$word_lower"
            FW_INDEX=$i
            break 2
        fi
    done
done

# Also catch multi-word framework spelling: "Swift Data", "Core Data",
# "Foundation Models", "Network Extension", etc.
if [[ $FW_INDEX -lt 0 ]]; then
    COMPACT_QUERY=""
    for word in "${ARGS[@]}"; do
        COMPACT_QUERY+="$(clean_token "$word")"
    done
    for fw in "${CANDIDATE_FRAMEWORKS[@]}"; do
        if [[ "$COMPACT_QUERY" == *"$fw"* ]]; then
            FRAMEWORK="$fw"
            FW_INDEX=1
            break
        fi
    done
fi

# Build the list of words excluding the framework word
if [[ $FW_INDEX -ge 0 ]]; then
    REMAINING=()
    for i in "${!ARGS[@]}"; do
        if [[ $i -ne $FW_INDEX ]]; then
            REMAINING+=("${ARGS[$i]}")
        fi
    done

    # Framework found mid-query (not at position 0) → natural language.
    # Framework at start with 3+ remaining → natural language.
    # Framework at start with 1–2 remaining → strict symbol lookup.
    if $HAS_QUERY_INTENT; then
        IS_NATURAL_LANGUAGE=true
    elif [[ $FW_INDEX -gt 0 ]]; then
        IS_NATURAL_LANGUAGE=true
    elif [[ ${#REMAINING[@]} -ge 3 ]]; then
        IS_NATURAL_LANGUAGE=true
    elif [[ ${#REMAINING[@]} -ge 1 ]]; then
        SYMBOL=$(build_symbol_path "${REMAINING[@]}")
    fi
else
    # No framework found in the query.
    if $HAS_QUERY_INTENT; then
        IS_NATURAL_LANGUAGE=true
    elif [[ ${#ARGS[@]} -ge 3 ]]; then
        IS_NATURAL_LANGUAGE=true
    else
        # 1 or 2 arguments, could be a symbol like "Task" or "URLSessionConfiguration default"
        SYMBOL=$(build_symbol_path "${ARGS[@]}")
    fi
fi

doc_context=""
EXTRACTED_SYMBOL=""

if $IS_NATURAL_LANGUAGE; then
    # Smart keyword extraction: scan RAW_QUERY for common symbols
    for word in "${ARGS[@]}"; do
        clean_lower=$(clean_token "$word")
        if [[ -n "$FRAMEWORK" && "$clean_lower" == "$FRAMEWORK" ]]; then
            continue
        fi
        for sym in "${COMMON_SYMBOLS[@]}"; do
            sym_lower=$(echo "$sym" | tr '[:upper:]' '[:lower:]')
            if [[ "$clean_lower" == "$sym_lower" ]]; then
                EXTRACTED_SYMBOL="$clean_lower"
                break 2
            fi
        done
    done

    if [[ -n "$EXTRACTED_SYMBOL" ]]; then
        echo -e "\033[90mExtracted keyword '$EXTRACTED_SYMBOL'. Grounding query with Apple docs...\033[0m"
    fi
fi

extract_explicit_tags

DOC_QUERY=$(build_probable_doc_query)

# Search Apple docs first using the most probable documentation query.
search_and_fetch_docs "$DOC_QUERY" || true

# Search failed — try direct fetch heuristics.
if [[ -z "$doc_context" ]]; then
    if $IS_NATURAL_LANGUAGE; then
        if [[ -n "$EXTRACTED_SYMBOL" ]]; then
            if [[ -n "$FRAMEWORK" ]]; then
                echo -e "\033[90mFetching Apple docs for $FRAMEWORK/$EXTRACTED_SYMBOL...\033[0m"
                doc_context=$(fetch_docs "$FRAMEWORK" "$EXTRACTED_SYMBOL")
                [[ -n "$doc_context" ]] && SYMBOL="$EXTRACTED_SYMBOL"
            fi
            if [[ -z "$doc_context" ]]; then
                for fw in "${CANDIDATE_FRAMEWORKS[@]}"; do
                    [[ -n "$FRAMEWORK" && "$fw" == "$FRAMEWORK" ]] && continue
                    echo -e "\033[90mChecking $fw/$EXTRACTED_SYMBOL...\033[0m"
                    doc_context=$(fetch_docs "$fw" "$EXTRACTED_SYMBOL")
                    if [[ -n "$doc_context" ]]; then
                        FRAMEWORK="$fw"
                        SYMBOL="$EXTRACTED_SYMBOL"
                        break
                    fi
                done
            fi
        fi

        if [[ -z "$doc_context" && -n "$FRAMEWORK" ]]; then
            echo -e "\033[90mFetching Apple docs for $FRAMEWORK...\033[0m"
            doc_context=$(fetch_docs "$FRAMEWORK" "")
            if [[ -n "$doc_context" ]]; then
                SYMBOL="$FRAMEWORK"
            fi
        fi
    else
        if [[ -n "$FRAMEWORK" ]]; then
            echo -e "\033[90mFetching Apple docs for $FRAMEWORK/$SYMBOL...\033[0m"
            doc_context=$(fetch_docs "$FRAMEWORK" "$SYMBOL")
        elif [[ -n "$SYMBOL" ]]; then
            for fw in "${CANDIDATE_FRAMEWORKS[@]}"; do
                echo -e "\033[90mChecking $fw/$SYMBOL...\033[0m"
                doc_context=$(fetch_docs "$fw" "$SYMBOL")
                if [[ -n "$doc_context" ]]; then
                    FRAMEWORK="$fw"
                    break
                fi
            done
        fi
    fi
fi

if [[ -z "$doc_context" && "$DOC_QUERY" != "$RAW_QUERY" ]]; then
    search_and_fetch_docs "$RAW_QUERY" || true
fi

SYSTEM="You are an expert iOS/macOS systems architect and lead Swift developer. 
Based on the provided Apple Developer API documentation, explain the symbol and how it works.
If no documentation context is supplied, use your general knowledge of Apple developer frameworks to answer the query (prefer SwiftUI and modern Swift concurrency by default unless UIKit/AppKit is explicitly requested).

Provide:
1. A concise, highly professional 2-3 sentence overview detailing what the component is, what it communicates with, and best practices.
2. A beautiful, realistic, state-of-the-art Swift code snippet demonstrating a typical production usage pattern. Ensure strict modern concurrency conventions (e.g. @MainActor, async/await, Sendable) are respected where appropriate."

prompt_payload=""
if [[ -n "$doc_context" ]]; then
    if $IS_NATURAL_LANGUAGE; then
        prompt_payload="Documentation Context (for '$SYMBOL' in $FRAMEWORK):
$doc_context

User Query: $RAW_QUERY"
    else
        prompt_payload="Documentation Context:
$doc_context

User Query: Explain $SYMBOL inside $FRAMEWORK and show how to use it."
    fi
else
    # Fallback to direct general query
    if $IS_NATURAL_LANGUAGE; then
        echo -e "\033[90mProcessing natural language query with local Apple Intelligence...\033[0m"
        if [[ -n "$FRAMEWORK" ]]; then
            prompt_payload="Framework Context: This query is about the $FRAMEWORK framework in Apple development.

User Query: $RAW_QUERY"
        else
            prompt_payload="User Query: $RAW_QUERY"
        fi
    else
        echo -e "\033[90mNo offline documentation found. Querying local Apple Intelligence directly...\033[0m"
        prompt_payload="User Query: Explain the Apple developer component or symbol '$SYMBOL' and show how to use it in modern Swift/iOS/macOS development."
    fi
fi

result=$(echo "$prompt_payload" | apfel -q -s "$SYSTEM")
status=$?

if [[ $status -ne 0 ]]; then
    echo "Error: apfel failed (exit $status)" >&2
    if [[ -n "$doc_context" ]]; then
        echo -e "\n--- Local Doc Extraction Fallback ---\n"
        echo "$doc_context"
    fi
    exit $status
fi

if $COPY; then
    echo "$result" | pbcopy
    echo -e "\033[90m(copied to clipboard)\033[0m"
fi

echo "$result"
"""#,

        "docs_apple_parser": #"""
import sys
import json

def extract_inline_content(elements, references):
    if not elements:
        return ""
    text = ""
    for elem in elements:
        e_type = elem.get('type')
        if e_type == 'text':
            text += elem.get('text', '')
        elif e_type == 'codeVoice':
            text += f"`{elem.get('code', '')}`"
        elif e_type == 'reference':
            ref_id = elem.get('identifier', '')
            if ref_id:
                ref_data = references.get(ref_id, {})
                ref_title = ref_data.get('title', '')
                if ref_title:
                    text += f"`{ref_title}`"
                else:
                    fallback = ref_id.rstrip('/').split('/')[-1]
                    if fallback:
                        text += f"`{fallback}`"
        elif e_type == 'strong':
            text += f"**{elem.get('strong', '')}**"
        elif e_type == 'emphasis':
            text += f"*{elem.get('emphasis', '')}*"
    return text

def parse_content_block(block, references):
    b_type = block.get('type')
    if b_type == 'heading':
        level = block.get('level', 3)
        inline = block.get('inlineContent', [])
        if inline:
            heading_text = extract_inline_content(inline, references)
        else:
            heading_text = block.get('text', '')
        return f"{'#' * level} {heading_text}"
    elif b_type == 'paragraph':
        return extract_inline_content(block.get('inlineContent', []), references)
    elif b_type == 'codeListing':
        code = "\n".join(block.get('code', []))
        syntax = block.get('syntax', 'swift')
        return f"```{syntax}\n{code}\n```"
    elif b_type == 'unorderedList' or b_type == 'orderedList':
        list_items = []
        for index, item in enumerate(block.get('items', [])):
            item_content = item.get('content', [])
            item_text = ""
            for ic in item_content:
                item_text += parse_content_block(ic, references)
            prefix = f"{index + 1}. " if b_type == 'orderedList' else "* "
            list_items.append(f"{prefix}{item_text}")
        return "\n".join(list_items)
    return ""

def parse_docc_json(data):
    title = data.get('metadata', {}).get('title', '')
    role = data.get('metadata', {}).get('roleHeading', '')
    references = data.get('references', {})
    
    # 1. Parse Abstract
    abstract_text = extract_inline_content(data.get('abstract', []), references)
            
    # 2. Parse Primary Content Sections
    sections_text = []
    for section in data.get('primaryContentSections', []):
        kind = section.get('kind')
        if kind == 'declarations':
            decs = section.get('declarations', [])
            if decs:
                tokens = decs[0].get('tokens', [])
                sig = "".join([t.get('text', '') for t in tokens])
                sections_text.append(f"## Declaration\n```swift\n{sig}\n```")
        elif kind == 'parameters':
            params_text = ["## Parameters\n"]
            for param in section.get('parameters', []):
                name = param.get('name', '')
                content = param.get('content', [])
                desc = ""
                for block in content:
                    desc += parse_content_block(block, references)
                params_text.append(f"* **{name}**: {desc}")
            sections_text.append("\n".join(params_text))
        elif kind == 'content':
            content_blocks = section.get('content', [])
            overview_text = []
            for block in content_blocks:
                p = parse_content_block(block, references)
                if p:
                    overview_text.append(p)
            if overview_text:
                sections_text.append("\n\n".join(overview_text[:8]))
                
    output = []
    output.append(f"# {role} {title}\n")
    if abstract_text:
        output.append(abstract_text + "\n")
    output.extend(sections_text)
    
    return "\n\n".join(output)

if __name__ == '__main__':
    try:
        raw_data = json.load(sys.stdin)
        parsed_md = parse_docc_json(raw_data)
        print(parsed_md)
    except Exception as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)
"""#,

        "trim_context": #"""
#!/usr/bin/env python3
"""Trim Markdown documentation for a small LLM context window.

Keeps high-value DocC sections first (overview, declaration, parameters), drops
navigation-heavy sections, then fills remaining budget with other sections.
The token count is approximate: 1 token ~= 4 characters.
"""

import argparse
import re
import sys


DROP_HEADINGS = (
    "inherited by",
    "conforms to",
    "conforming types",
    "relationships",
    "see also",
)

PRIORITY_HEADINGS = (
    "overview",
    "declaration",
    "discussion",
    "parameters",
    "creating",
    "using",
    "usage",
)


def section_title(line):
    match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
    return match.group(2).strip() if match else None


def split_sections(text):
    sections = []
    current = {"title": "", "lines": []}
    for line in text.splitlines():
        title = section_title(line)
        if title is not None:
            sections.append(current)
            current = {"title": title, "lines": [line]}
        else:
            current["lines"].append(line)
    sections.append(current)
    return [section for section in sections if section["lines"]]


def should_drop(title):
    lower = title.lower()
    return any(marker in lower for marker in DROP_HEADINGS)


def priority(title):
    if not title:
        return 0
    lower = title.lower()
    if any(marker in lower for marker in PRIORITY_HEADINGS):
        return 1
    return 2


def section_text(section):
    return "\n".join(section["lines"]).strip() + "\n"


def trim_to_chars(text, max_chars):
    if len(text) <= max_chars:
        return text.rstrip()
    clipped = text[:max_chars]
    last_newline = clipped.rfind("\n")
    if last_newline > max_chars * 0.75:
        clipped = clipped[:last_newline]
    return clipped.rstrip() + "\n\n[trimmed to fit context budget]"


def trim_markdown(text, max_tokens):
    max_chars = max(1000, max_tokens * 4)
    sections = [s for s in split_sections(text) if not should_drop(s["title"])]

    selected = set()
    used = 0
    for wanted_priority in (0, 1, 2):
        for index, section in enumerate(sections):
            if index in selected or priority(section["title"]) != wanted_priority:
                continue
            text_part = section_text(section)
            if used + len(text_part) <= max_chars:
                selected.add(index)
                used += len(text_part)
            elif wanted_priority < 2 and max_chars - used > 800:
                selected.add(index)
                used = max_chars
                break
        if used >= max_chars:
            break

    output = "\n".join(section_text(sections[i]).rstrip() for i in sorted(selected)).strip()
    return trim_to_chars(output, max_chars)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-tokens", type=int, default=2000)
    args = parser.parse_args()
    print(trim_markdown(sys.stdin.read(), args.max_tokens))


if __name__ == "__main__":
    main()
"""#,

        "mdn": #"""
#!/bin/bash
# mdn — search MDN Web Docs from apfel --chat
# Usage: /mdn [--1000|--2000|--3000] [@keyword] [query...]
# Output is captured by apfel and injected into the model's context.

MDN_BUDGET=1000
ARGS=()
EXPLICIT_TAGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --[0-9]*) MDN_BUDGET="${1#--}"; shift ;;
        @*) EXPLICIT_TAGS+=("${1#@}"); shift ;;
        -h|--help)
            echo "mdn — search MDN Web Docs from apfel --chat"
            echo ""
            echo "Usage: /mdn [--1000|--2000|--3000] [@keyword] <query>"
            echo ""
            echo "  --1000  Default budget (~250 tokens)"
            echo "  --2000  Double budget (~500 tokens)"  
            echo "  --3000  Triple budget (~750 tokens)"
            echo "  @tag    Explicit keyword tag (use multiple for compound query)"
            echo ""
            echo "Examples:"
            echo "  /mdn CSS flexbox"
            echo "  /mdn @flexbox"
            echo "  /mdn --2000 Array.prototype.map"
            exit 0 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

# Build query: explicit @tags take priority, else join all positional args
if [[ ${#EXPLICIT_TAGS[@]} -gt 0 ]]; then
    QUERY="${EXPLICIT_TAGS[*]}"
else
    QUERY="${ARGS[*]}"
fi

if [[ -z "$QUERY" ]]; then
    echo "Error: no query provided. Usage: /mdn [--2000] <query>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER_PATH="$SCRIPT_DIR/helpers/mdn_doc_parser.py"
TRIM_PATH="$SCRIPT_DIR/helpers/trim_mdn.py"

# URL-encode via python3 (avoids bash quoting issues with special chars)
url_encode() {
    python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# Step 1: Search MDN
ENCODED=$(url_encode "$QUERY")
SEARCH_RESPONSE=$(curl -s --connect-timeout 10 --max-time 15 \
    "https://developer.mozilla.org/api/v1/search?q=${ENCODED}&locale=en-US" 2>/dev/null)

if [[ -z "$SEARCH_RESPONSE" ]]; then
    echo "No MDN results for '$QUERY'." >&2
    exit 1
fi

# Step 2: Extract top result path
TOP_PATH=$(echo "$SEARCH_RESPONSE" | python3 -c "
import json,sys
try:
    docs = json.load(sys.stdin).get('documents', [])
    if docs:
        print(docs[0].get('mdn_url', ''))
    else:
        sys.exit(1)
except:
    sys.exit(1)
")
[[ -z "$TOP_PATH" ]] && { echo "No MDN results for '$QUERY'." >&2; exit 1; }

# Step 3: Fetch doc JSON
DOC_JSON=$(curl -s --connect-timeout 10 --max-time 15 \
    "https://developer.mozilla.org${TOP_PATH}/index.json" 2>/dev/null)

if [[ -z "$DOC_JSON" ]]; then
    echo "No MDN results for '$QUERY'." >&2
    exit 1
fi

# Step 4: Parse + trim. Fall back to title+summary if helpers are missing.
if [[ -f "$PARSER_PATH" && -f "$TRIM_PATH" ]]; then
    echo "$DOC_JSON" | python3 "$PARSER_PATH" 2>/dev/null | python3 "$TRIM_PATH" --max-chars "$MDN_BUDGET"
else
    echo "$DOC_JSON" | python3 -c "
import json,sys
doc = json.load(sys.stdin).get('doc', {})
print('#', doc.get('title', ''))
print()
print(doc.get('summary', ''))
"
fi
"""#,

        "mdn_doc_parser": #"""
#!/usr/bin/env python3
"""Parse MDN index.json into clean text for LLM consumption.

Reads MDN doc JSON from stdin, extracts structured content:
title, summary, syntax, parameters, return value, description, examples.
Drops: specifications, browser compatibility tables, see also links.
Converts prose HTML blocks to readable plain text.
"""

import json
import re
import sys


DROP_TITLES = {
    'see also', 'specifications', 'browser compatibility',
    'formal definition', 'formal syntax',
}

KEEP_TITLES = {
    'syntax', 'parameters', 'return value', 'description',
    'examples', 'usage notes', 'accessibility', 'exceptions',
    'constructor', 'properties', 'methods', 'events',
    'static methods', 'instance methods', 'instance properties',
    'values', 'value', 'type', 'return type',
}


def strip_html(text):
    """Convert MDN prose HTML blocks to readable plain text."""
    text = re.sub(r'<pre[^>]*><code[^>]*>', '\n```\n', text)
    text = re.sub(r'</code></pre>', '\n```\n', text)
    text = re.sub(r'<code[^>]*>', '`', text)
    text = re.sub(r'</code>', '`', text)
    text = re.sub(r'<br\s*/?>', '\n', text)
    text = re.sub(r'<p[^>]*>', '', text)
    text = re.sub(r'</p>', '\n\n', text)
    text = re.sub(r'<li[^>]*>', '* ', text)
    text = re.sub(r'</li>', '\n', text)
    text = re.sub(r'<(ul|ol)[^>]*>', '', text)
    text = re.sub(r'</(ul|ol)>', '', text)
    for i in range(1, 7):
        text = re.sub(rf'<h{i}[^>]*>', '#' * i + ' ', text)
        text = re.sub(rf'</h{i}>', '', text)
    text = re.sub(r'<strong[^>]*>', '**', text)
    text = re.sub(r'</strong>', '**', text)
    text = re.sub(r'<em[^>]*>', '*', text)
    text = re.sub(r'</em>', '*', text)
    text = re.sub(r'<a[^>]*>', '', text)
    text = re.sub(r'</a>', '', text)
    text = re.sub(r'<(table|thead|tbody|tr|th|td|dl|dt|dd|section|div|span|figure|img|svg|nav|header|footer)[^>]*>', '', text)
    text = re.sub(r'</(table|thead|tbody|tr|th|td|dl|dt|dd|section|div|span|figure|img|svg|nav|header|footer)>', '', text)
    text = re.sub(r'<[^>]+>', '', text)
    text = text.replace('&lt;', '<').replace('&gt;', '>').replace('&amp;', '&')
    text = text.replace('&quot;', '"').replace('&#x27;', "'").replace('&#39;', "'")
    text = text.replace('&nbsp;', ' ')
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r' {2,}', ' ', text)
    return text.strip()


def main():
    data = json.load(sys.stdin)
    doc = data.get('doc', {})

    output = []

    title = doc.get('title', '')
    if title:
        output.append('# ' + title)
        output.append('')

    summary = doc.get('summary', '')
    if summary:
        output.append(summary)
        output.append('')

    body = doc.get('body', [])
    for block in body:
        if block.get('type') != 'prose':
            continue

        value = block.get('value', {})
        section_title = (value.get('title') or '').strip()
        content_html = value.get('content', '')

        if not content_html:
            continue

        lower_title = section_title.lower()
        if lower_title in DROP_TITLES:
            continue

        content_text = strip_html(content_html)
        if not content_text:
            continue

        if section_title and lower_title not in KEEP_TITLES:
            output.append('## ' + section_title)
        output.append(content_text)
        output.append('')

    print('\n'.join(output).strip())


if __name__ == '__main__':
    main()
"""#,

        "trim_mdn": #"""
#!/usr/bin/env python3
"""Trim MDN documentation text to fit a character budget.

1 character ~= 0.25 tokens. Works with mdn_doc_parser output.
Prioritizes: syntax, description, parameters, return value, examples.
Drops: see also, specifications, browser compatibility.
"""

import argparse
import re
import sys


DROP_HEADINGS = (
    'see also',
    'specifications',
    'browser compatibility',
    'formal definition',
    'formal syntax',
)

PRIORITY_HEADINGS = (
    'syntax',
    'description',
    'parameters',
    'return value',
    'examples',
    'constructor',
    'properties',
    'methods',
    'events',
    'accessibility',
    'exceptions',
    'usage',
)


def section_title(line):
    m = re.match(r'^(#{1,6})\s+(.+?)\s*$', line)
    return m.group(2).strip() if m else None


def split_sections(text):
    sections = []
    current = {'title': '', 'lines': []}
    for line in text.splitlines():
        title = section_title(line)
        if title is not None:
            sections.append(current)
            current = {'title': title, 'lines': [line]}
        else:
            current['lines'].append(line)
    sections.append(current)
    return [s for s in sections if s['lines']]


def should_drop(title):
    lower = title.lower()
    return any(m in lower for m in DROP_HEADINGS)


def priority(title):
    if not title:
        return 0
    lower = title.lower()
    if any(m in lower for m in PRIORITY_HEADINGS):
        return 1
    return 2


def section_text(section):
    return '\n'.join(section['lines']).strip() + '\n'


def trim_to_chars(text, max_chars):
    if len(text) <= max_chars:
        return text.rstrip()
    clipped = text[:max_chars]
    last_newline = clipped.rfind('\n')
    if last_newline > max_chars * 0.75:
        clipped = clipped[:last_newline]
    return clipped.rstrip() + '\n\n[... trimmed to fit context budget]'


def trim_markdown(text, max_chars):
    sections = [s for s in split_sections(text) if not should_drop(s['title'])]
    selected = set()
    used = 0
    for wanted_priority in (0, 1, 2):
        for idx, section in enumerate(sections):
            if idx in selected or priority(section['title']) != wanted_priority:
                continue
            text_part = section_text(section)
            if used + len(text_part) <= max_chars:
                selected.add(idx)
                used += len(text_part)
            elif wanted_priority < 2 and max_chars - used > 500:
                selected.add(idx)
                used = max_chars
                break
        if used >= max_chars:
            break
    output = '\n'.join(section_text(sections[i]).rstrip() for i in sorted(selected)).strip()
    return trim_to_chars(output, max_chars)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--max-chars', type=int, default=1000)
    args = parser.parse_args()
    print(trim_markdown(sys.stdin.read(), args.max_chars))


if __name__ == '__main__':
    main()
"""#
    ]
}
