# apfel demos

Real-world shell scripts powered by Apple Intelligence via `apfel`.

All demos work within the 4096-token context window - small input, small output, instant results.

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

## wtd

What's this directory? Instant orientation in any project.

```bash
./wtd                    # current directory
./wtd ~/some/project     # any directory
./wtd -c .               # copy summary to clipboard
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
Process 1234, named node, is listening on port 3000 - this is likely
a Node.js development server (Express, Next.js, or similar).
```

## process

What's this process about? Identifies the process by PID, checks open files and network descriptors, and explains what it is.

```bash
./process 648
./process 1234 -c    # copy to clipboard
```

**Example output:**
```
Process 648, named rapportd, is running under user bogdan. It is a native macOS daemon responsible for device-to-device communication such as AirDrop, Handoff, and Apple Watch unlocking.
```

## daemon

What's this macOS daemon, system service, or command about? Explains what it does and how it internally works.

```bash
./daemon mDNSResponder
./daemon configd -c    # copy to clipboard
```

**Example output:**
```
mDNSResponder is a macOS daemon that is responsible for responding to Domain Name System (DNS) queries from other devices on the same network. It is a critical component of macOS's networking infrastructure, enabling features such as AirDrop, iCloud, and Apple TV Remote Control. It manages interactions with DNS resolvers and handles multicast DNS queries using a combination of UDP and TCP protocols.
```

## docs-apple

Smart developer documentation, code helper, and conversational assistant.

Queries are classified to build the best Apple docs search query: framework names are detected anywhere in the input, common symbols are extracted as search hints, and intent words (explain, what, how) are filtered out. Apple docs search always runs first; direct framework/symbol fetches are fallback heuristics. Fetched documentation is pruned structurally before it enters the prompt. Model-only answering is the final fallback.

Explicit `@keyword` control bypasses all auto-detection and uses the tagged words directly as the Apple docs search query.

```bash
./docs-apple SwiftUI Button                   # Framework + symbol
./docs-apple Task                              # Symbol lookup across frameworks
./docs-apple i want to build a View with italic text  # Keyword extraction from natural language
./docs-apple --3000 SwiftData                  # Allow ~3000 doc-context tokens
./docs-apple --1000 explain "SwiftData"        # Intent query + quoted framework
./docs-apple --no-sosumi SwiftUI Button        # Force native curl/parser path
./docs-apple Combine Publisher -c             # Copy output to clipboard
```

**Example output:**
```
Extracted keyword 'view'. Grounding query with Apple docs...
### Overview
The View protocol defines a type that represents part of the user interface of a SwiftUI application...

### Code Snippet
[Beautiful, grounded, offline-generated Swift / SwiftUI code snippet]
```

**How arguments are classified:**

Framework names are detected **anywhere** in the query (not just the first word). Quotes and punctuation are stripped before detection, so `"SwiftData"` becomes `swiftdata`. Multi-word spelling is compacted too: `Swift Data` → `swiftdata`, `Foundation Models` → `foundationmodels`, `Core Data` → `coredata`.

Intent words (`explain`, `what`, `how`, `why`, `show`, `tell`, `overview`, `summarize`, `summary`, `describe`) do not bypass Apple docs. They are filtered out of the probable docs query so apfel searches for the API/framework, not the prose instruction.

**Explicit `@keyword` control:** prefix any word with `@` to force it as the exact Apple docs search term. Bypasses all auto-detection and stop-word filtering. Works unquoted in both terminal and chat mode (`@` has no special shell meaning).

```bash
./docs-apple @CoreData
./docs-apple @SwiftUI @NavigationSplitView
./docs-apple explain @NetworkExtension in a few sentences
./docs-apple @WidgetKit how to build a widget
```

| Input | Framework | Position | Remaining | Mode |
|-------|-----------|----------|-----------|------|
| `SwiftUI Button` | swiftui | start | 1 | Search Apple docs for `swiftui button`, then fetch best result |
| `SwiftUI "Button"` | swiftui | start | 1 | Quotes stripped → search `swiftui button` |
| `Combine Publisher` | combine | start | 1 | Search Apple docs for `combine publisher` |
| `Combine framework explain in few sentences` | combine | start | 5 (≥ 3) | Search Apple docs for `combine` |
| `explain in few sentences Combine framework` | combine | mid-query (pos 4) | — | Search Apple docs for `combine` |
| `explain "SwiftData"` | swiftdata | mid-query | — | Search Apple docs for `swiftdata` |
| `explain Combine Publisher` | combine | mid-query (pos 1) | — | Search Apple docs for `combine publisher` |
| `Button SwiftUI` | swiftui | mid-query (pos 1) | — | Search Apple docs for `swiftui button` |
| `Task` | — | — | 1 | Search Apple docs for `task` |

Framework and symbol detection build the most probable Apple docs query. Apple docs search runs first; direct `framework/symbol` or framework-root fetches are fallback heuristics if search fails. Model-only answering is the final fallback, not the normal natural-language path.
The common-symbol list is broad: SwiftUI, Swift concurrency, Foundation, SwiftData/Core Data, Combine, UIKit/AppKit, graphics/media/location/security/networking, StoreKit, WidgetKit, Vision, WebKit, XCTest, and logging symbols. The framework/symbol lists are hints, not a requirement for docs search.
Fetched documentation is pruned before it enters the prompt. Default budget is about 2,000 tokens; use `--1000`, `--3000`, etc. to tune it per query.
The `-c` (copy to clipboard) flag works from the terminal but is blocked inside `--chat` mode — run `apfel docs-apple -c` directly.

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
[14:23:07] Ah, the eternal dance - Claude Code consuming 8.2% CPU whilst
its human presumably waits for it to finish. Meanwhile, WindowServer
soldiers on at 3.1%, dutifully rendering pixels that nobody is looking at.
```

## Requirements

- `apfel` installed and on PATH (`make install`)
- Apple Intelligence enabled in System Settings
- macOS 26+, Apple Silicon

## Running Demos Globally & Self-Contained Execution

All premium developer utilities (`cmd`, `oneliner`, `naming`, `explain`, `wtd`, `port`, `process`, `daemon`, `docs-apple`, `mdn`) are now **fully built-in, first-class features of `apfel`**.

### 1. Direct Built-In Execution
You can run any developer tool directly via the `apfel` binary:
```bash
apfel port 3000
apfel wtd ~/projects/my-app
apfel docs-apple SwiftUI Button
apfel mdn CSS flexbox
```
This executes **instantly** by taking a compiled-in fast path that completely bypasses loading time or model availability checks.

### 2. Stateful Interactive Chat Mode
These tools are fully integrated into `--chat` mode using **slash commands**. In your chat session, prefix the tool name with `/`:
```
you› /port 3000
you› /explain awk -F: '{print $1}' /etc/passwd
you› /docs-apple SwiftUI Button
you› /mdn CSS flexbox
you› /wtd ~/projects/my-app
you› /cmd find large files
```
`apfel` intercepts the slash command, runs the built-in script instantly (no model startup), and **re-injects the tool output back into the stateful chat transcript** so you can ask follow-up questions!

**Why the slash prefix?** Bare words without `/` always go to the LLM. This means you can freely ask the model:
```
you› explain how recursion works         ← goes to the LLM
you› /explain how recursion works        ← runs the explain tool
you› port is important in networking     ← goes to the LLM
you› /port 3000                          ← runs the port tool
```

**Session controls** also use slash syntax:
```
you› /clear    ← erase terminal screen (context kept)
you› /new      ← erase screen + reset to a completely fresh session
you› /context  ← print current context-window usage
```

### 3. Dynamic Global Command Invocation
Every tool script is compiled into the `apfel` binary. When you run any tool, the binary dynamically extracts the script to your home directory at `~/.apfel/bin/apfel-<name>` and makes it executable.

To use the `apfel-` prefix commands globally without keeping the clone directory on disk:
1. Add the extracted directory to your `$PATH`:
   ```bash
   echo 'export PATH="$HOME/.apfel/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```
2. Simply invoke them globally:
   ```bash
   apfel-port 3000
   apfel-explain "error: url not found"
   ```

### 4. Direct Aliasing (Recommended)
To run the short commands directly (e.g. `port 3000` or `wtd`) without typing `apfel-` or `apfel `, add these clean aliases to your `~/.zshrc`:
```bash
alias wtd="apfel wtd"
alias port="apfel port"
alias process="apfel process"
alias daemon="apfel daemon"
alias explain="apfel explain"
alias cmd="apfel cmd"
alias oneliner="apfel oneliner"
alias naming="apfel naming"
alias docs-apple="apfel docs-apple"
alias mdn="apfel mdn"
```
