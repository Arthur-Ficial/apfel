# apfel demos

Real-world shell scripts powered by Apple Intelligence via `apfel`.

All demos work within the 4096-token context window — small input, small output, instant results.

## cmd

Natural language to shell command. Faster than Googling, works offline.

```bash
./cmd "find all .log files modified today"
$ find . -name "*.log" -type f -mtime -1

./cmd -c "disk usage sorted by size"    # copy to clipboard
./cmd -x "show open ports"              # execute (asks confirmation)
```

## oneliner

Complex pipe chains from plain English. Specializes in awk, sed, find, xargs, sort, uniq, grep, cut, tr, jq.

```bash
./oneliner "sum the third column of a CSV"
$ awk -F',' '{sum += $3} END {print sum}' file.csv

./oneliner "count unique IPs in access.log"
$ awk '{print $1}' access.log | sort | uniq -c | sort -rn

./oneliner -c "remove duplicate lines keeping order"    # copy to clipboard
./oneliner -x "sort processes by memory"                # execute (asks confirmation)
```

## wtf

What is this directory? Instant orientation in any project.

```bash
./wtf                    # current directory
./wtf ~/some/project     # any directory
./wtf -c .               # copy summary to clipboard
```

Checks file listing, README, package.json/Package.swift/Cargo.toml/go.mod, git branch and last commit, then tells you what this project is, what language, and how to run it.

**Example output:**

```
The directory /Users/you/dev/apfel contains a Swift package project that
appears to be a macOS application. It utilizes Swift 6.2 and the Swift
Package Manager (SPM). To build or run the project, use swift build.
```

## explain

Explain a command, error message, or code snippet.

```bash
./explain "awk -F: '{print \$1,\$3}' /etc/passwd | sort -t' ' -k2 -n"
./explain "error: use of undeclared identifier 'URLSession'"
./explain "curl -sSL -o /dev/null -w '%{http_code}'"
pbpaste | ./explain       # explain whatever's on clipboard
dmesg | tail -5 | ./explain
```

**Example output:**

```
This command processes /etc/passwd, extracting the username (field 1) and
user ID (field 3) using colon as delimiter, then sorts the output
numerically by user ID.
```

## naming

Name things well. Describe what something does, get naming suggestions.

```bash
./naming "function that retries HTTP requests with exponential backoff"
./naming "variable for the count of failed login attempts"
./naming "class that manages WebSocket connections"
./naming -c "file containing database migration scripts"    # copy to clipboard
```

**Example output:**

```
retryWithBackoff | retry_with_backoff | retries with exponential delay
httpRetryHandler | http_retry_handler | handles HTTP retry logic
fetchWithRetry | fetch_with_retry | fetch with automatic retries
resilientRequest | resilient_request | request that survives failures
backoffExecutor | backoff_executor | executes with increasing delays
```

## port

What's using this port? Identifies the process and explains what it is.

```bash
./port 3000
./port 8080
./port 5432
./port -c 3000    # copy to clipboard
```

**Example output:**

```
Process 1234, named node, is listening on port 3000 — this is likely
a Node.js development server (Express, Next.js, or similar).
```

## gitsum

Summarize recent git activity in plain English.

```bash
./gitsum          # last 10 commits
./gitsum 20       # last 20 commits
./gitsum -c       # copy summary to clipboard
```

**Example output:**

```
Recent work focused on adding tool calling documentation with real experiment
results, implementing OpenAPI schema validation tests, and adding cmd and
oneliner demo scripts. Documentation was also rewritten for the README.
```

## mac-narrator

Your Mac's inner monologue. Narrates system state in dry British humor.

```bash
./mac-narrator                    # one-shot observation
./mac-narrator --watch            # continuous, every 60s
./mac-narrator --watch -i 30      # every 30 seconds
```

**Example output:**

```
[14:23:07] Ah, the eternal dance — Claude Code consuming 8.2% CPU whilst
its human presumably waits for it to finish. Meanwhile, WindowServer
soldiers on at 3.1%, dutifully rendering pixels that nobody is looking at.
```

## Requirements

- `apfel` installed and on PATH (`make install`)
- Apple Intelligence enabled in System Settings
- macOS 26+, Apple Silicon
