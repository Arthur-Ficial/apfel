# apfel demos

Real-world shell scripts powered by Apple Intelligence via `apfel`.

All demos work within the 4096-token context window — small input, small output, instant results.

## cmd

Natural language to shell command. Faster than Googling, works offline.

```bash
# Basic usage
./cmd "find all .log files modified today"
$ find . -name "*.log" -type f -mtime -1

./cmd "kill all node processes"
$ killall node

./cmd "list all listening ports on this mac"
$ sudo netstat -lntu | grep :

# Copy to clipboard
./cmd -c "disk usage sorted by size"
(copied to clipboard)
$ du -sh * | sort -hr

# Execute immediately (asks confirmation)
./cmd -x "show disk usage sorted by size"
$ du -sh * | sort -hr

Run this? [y/N] y
```

## oneliner

Complex pipe chains from plain English. Specializes in awk, sed, find, xargs, sort, uniq, grep, cut, tr, jq.

```bash
# Basic usage
./oneliner "sum the third column of a CSV"
$ awk -F',' '{sum += $3} END {print sum}' file.csv

./oneliner "count unique IPs in access.log"
$ awk '{print $1}' access.log | sort | uniq -c | sort -rn

./oneliner "extract all URLs from a file"
$ grep -oE 'https?://[^ ]+' file.txt

# Copy to clipboard
./oneliner -c "remove duplicate lines keeping order"
(copied to clipboard)
$ awk '!seen[$0]++' file.txt

# Execute (asks confirmation)
./oneliner -x "count lines of code per swift file sorted descending"
$ find . -name '*.swift' -exec wc -l {} + | sort -rn
```

## mac-narrator

Your Mac's inner monologue. Collects system state (processes, memory, disk, battery) and narrates what's happening in dry British humor.

```bash
# One-shot — print a single observation and exit
./mac-narrator

# Watch mode — continuous narration every 60 seconds
./mac-narrator --watch

# Custom interval
./mac-narrator --watch --interval 30
```

**Example output:**

```
[14:23:07] Ah, the eternal dance — Claude Code consuming 8.2% CPU whilst
its human presumably waits for it to finish. Meanwhile, WindowServer
soldiers on at 3.1%, dutifully rendering pixels that nobody is looking at.

[14:24:07] Safari has spawned no fewer than 12 helper processes, collectively
hoarding 2.3GB of RAM. One suspects at least 11 of those tabs haven't been
looked at since Tuesday.
```

## Requirements

- `apfel` installed and on PATH (`make install`)
- Apple Intelligence enabled in System Settings
- macOS 26+, Apple Silicon
