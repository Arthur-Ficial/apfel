# apfel - Project Instructions

**The free AI already on your Mac.** This is our claim. Every surface (README, landing page, repo description) must reinforce it.

## The Golden Goal

apfel has ONE purpose with THREE delivery modes:

> **Expose Apple's on-device FoundationModels LLM as a usable, powerful UNIX tool
> and an OpenAI API-compatible server, with a working command-line chat.**

### The three modes, in priority order:

1. **UNIX tool** (`apfel "prompt"`, `echo "text" | apfel`, `apfel --stream`)
   - Pipe-friendly, composable, correct exit codes
   - Works with `jq`, `xargs`, shell scripts
   - `--json` output for machine consumption
   - Respects `NO_COLOR`, `--quiet`, stdin detection

2. **OpenAI-compatible HTTP server** (`apfel --serve`)
   - Drop-in replacement for `openai.OpenAI(base_url="http://localhost:11434/v1")`
   - `/v1/chat/completions` (streaming + non-streaming)
   - `/v1/models`, `/health`, tool calling, `response_format`
   - Honest 501s for unsupported features (embeddings, legacy completions)
   - CORS for browser clients

3. **Command-line chat** (`apfel --chat`)
   - Interactive multi-turn with context window protection
   - Typed error display, context rotation when approaching limit
   - System prompt support

The Debug GUI has been extracted to its own repo: [apfel-gui](https://github.com/Arthur-Ficial/apfel-gui)

### Non-negotiable principles:

- **100% on-device.** No cloud, no API keys, no network for inference. Ever.
- **Honest about limitations.** 4096 token context, no embeddings, no vision - say so clearly.
- **Clean code, clean logic.** No hacks. Proper error types. Real token counts.
- **Swift 6 strict concurrency.** No data races.
- **Usable security.** Secure defaults that don't get in the way.
- **TDD always, red-to-green, 100%.** No production code without a failing test first. Write the test, watch it fail for the right reason, write the minimal code to pass, watch it go green. No exceptions, no "I'll add tests after", no "this is too simple to test". Behavior-preserving refactors are covered by existing tests; new behavior gets a new failing test first.

### Documentation style:

- **Links in docs and README:** Always use the URL/path as the anchor text, not generic phrases like "full guide" or "click here". Example: `[docs/background-service.md](docs/background-service.md)` not `[full guide](docs/background-service.md)`.

## Architecture

```
CLI (single/stream/chat) ──┐
                           ├─→ Session.swift → FoundationModels (on-device)
HTTP Server (/v1/*) ───────┘   ContextManager → Transcript API
                                ContextStrategy → 5 trimming strategies
                                SchemaConverter → DynamicGenerationSchema
                                TokenCounter → real tokenCount (SDK 26.4)
```

- `ApfelCore` library: pure Swift, no FoundationModels dependency, unit-testable
- Main target: FoundationModels integration, Hummingbird HTTP server
- Tests: `swift run apfel-tests` (pure Swift runner, no XCTest needed)
- No Xcode required - builds with Command Line Tools only

## Current Status

- Version: `1.0.0` (source of truth: `.version`)
- Tests: 366 unit + 220 integration
- Distribution: homebrew-core (`brew install apfel`), nixpkgs (`nix profile install nixpkgs#apfel-ai`), and the Arthur-Ficial/homebrew-tap
- Stability policy: [STABILITY.md](STABILITY.md)
- Security policy: [SECURITY.md](SECURITY.md)

## Build & Test

```bash
make test                      # BUILD + ALL TESTS (unit + integration) - the one command you need
make install                   # build release + install to /usr/local/bin (NO version bump)
make build                     # build release only (NO version bump)
make version                   # print current version
swift build                    # debug build
swift run apfel-tests          # unit tests only (366 tests)
make preflight                 # full release qualification (unit + integration + policy checks)
```

`make test` builds the release binary, runs all 366 unit tests, starts test servers, runs all 220 integration tests, and cleans up. This is the single command for development.

`make install` auto-unlinks Homebrew apfel so the dev binary takes PATH priority. `make uninstall` restores the Homebrew link.

**Version is in `.version` file** (single source of truth). Local builds (`make build`, `make install`) do NOT change the version. Only the release workflow (`make release`) bumps versions. This ensures patch versions mean "published compatible fix", not "someone ran a build". **Never manually edit `.version`, `BuildInfo.swift`, or the README badge** - these are updated atomically by the release workflow.

Regenerate `docs/EXAMPLES.md` (runs 53 prompts against the installed binary, captures real unedited output):
```bash
bash scripts/generate-examples.sh          # ~2 minutes, overwrites docs/EXAMPLES.md
```

## Key Files

| Area | Files |
|------|-------|
| Entry point | `Sources/main.swift` |
| CLI commands | `Sources/CLI.swift` |
| HTTP server | `Sources/Server.swift`, `Sources/Handlers.swift` |
| Session mgmt | `Sources/Session.swift`, `Sources/ContextManager.swift` |
| Context strategies | `Sources/Core/ContextStrategy.swift`, `Sources/Summarizer.swift` |
| Tool calling | `Sources/Core/ToolCallHandler.swift`, `Sources/SchemaConverter.swift` |
| Token counting | `Sources/TokenCounter.swift` |
| Error types | `Sources/Core/ApfelError.swift` |
| Retry logic | `Sources/Core/Retry.swift` (withRetry, isRetryableError), `Sources/Retry.swift` (AsyncSemaphore) |
| Models/types | `Sources/Models.swift`, `Sources/ToolModels.swift` |
| Build info | `Sources/BuildInfo.swift` (auto-generated by `make`) |
| Security | `Sources/Core/OriginValidator.swift`, `Sources/SecurityMiddleware.swift` |
| MCP client | `Sources/Core/MCPProtocol.swift`, `Sources/MCPClient.swift` |
| MCP calculator | `mcp/calculator/server.py` |
| Tests | `Tests/apfelTests/` (335 unit), `Tests/integration/` (216 integration) |

| Docs | `docs/` (brew-install, EXAMPLES, release, tool-calling-guide) |
| Scripts | `scripts/generate-examples.sh`, `scripts/write-homebrew-formula.sh`, `scripts/release-preflight.sh`, `scripts/post-release-verify.sh` |

## Handling GitHub Issues

When a new issue comes in, follow this process:

1. **Fetch** the full issue with `gh issue view <n> --repo Arthur-Ficial/apfel --json body,comments,title,author,labels`
2. **Vet** - is it a real bug, valid feature request, or noise?
   - Does it align with the golden goal and non-negotiable principles?
   - Can you reproduce it?
   - Check comments for additional context and links
   - Verify the user's environment against known gotchas (macOS 26 Tahoe required, Apple Silicon only, Apple Intelligence enabled, Siri + device language match)
3. **Fix** if valid:
   - Write tests first (TDD) for bugs
   - Keep changes minimal and KISS
   - `make install` + run all tests (`swift run apfel-tests` + `python3 -m pytest Tests/integration/ -v`)
4. **Release** if code changed - see "Publishing a Release" below
5. **Close** the issue with a friendly, short, truthful comment:
   - What was the problem
   - What was fixed (or why it was closed without a fix)
   - How to update (`brew upgrade apfel`)
6. **Landing page** (apfel.franzai.com) is a separate Cloudflare Pages project, not in this repo

## Handling Pull Requests

When a PR is opened, follow this process. Scale the rigor to the PR type - docs-only PRs skip the security audit and test coverage steps, code PRs get the full treatment.

**Automated first-responder:** `Arthur-Ficial/apfel` has a Claude Code routine (`.claude/routines/02-pr-auto-review.md`) that runs this entire process on `pull_request.opened` / `pull_request.synchronize` and posts a `COMMENTED` review. The routine cannot `--approve`, cannot merge, cannot run `make test` (no Apple Intelligence on cloud runners), and cannot cut releases. It is a first-pass safety net, not a replacement for human judgement. Franz still merges, Franz still releases — always. See [docs/routines.md](docs/routines.md) and [.claude/routines/README.md](.claude/routines/README.md).

### 1. Fetch everything

```bash
gh pr view <n> --repo Arthur-Ficial/apfel --json title,author,body,state,mergeable,mergeStateStatus,reviews,comments,commits,statusCheckRollup,files,headRefName,headRepositoryOwner
gh pr diff <n> --repo Arthur-Ficial/apfel                             # full diff
gh api repos/Arthur-Ficial/apfel/pulls/<n>/comments                   # inline review comments
git fetch origin pull/<n>/head:pr-<n>-head && git checkout pr-<n>-head # actual tree
```

### 2. Vet the author

- First-time contributor to apfel? (`gh pr list --repo Arthur-Ficial/apfel --state all --author <login>`)
- Legitimate GitHub profile? Check `gh api users/<login>` for public_repos, followers, blog, creation date
- Commit author email matches the GitHub account (spot typo-squatting)
- Any red flags in prior public work

### 3. Classify the PR type

| Type | What it touches | Process depth |
|------|-----------------|---------------|
| **Docs-only** | `docs/**`, `README.md`, `CLAUDE.md` | Factual accuracy, link validity, alignment with golden goal, tone |
| **Test-only** | `Tests/**` | Test quality, no false positives/negatives, actually exercises new behavior |
| **Code: non-network** | `Sources/**` (no `URLSession`, `Process`, file I/O outside sandbox) | Full architecture + test coverage + build + tests |
| **Code: network/parsing/auth** | MCP, server, OpenAI handlers, auth, URL parsing | **Full security audit** on top of the code-PR process |
| **Build/CI** | `Package.swift`, `.github/workflows/**`, `Makefile`, `scripts/**` | Reproducibility check, supply chain (pinned versions), runner safety |

### 4. Read every changed file

No skimming. Use `git show pr-<n>-head:<path>` or read from the checked-out tree. For large PRs, map the changes before diving in: list files, group by concern, read in dependency order.

### 5. Security audit (code PRs, especially network/parsing/auth)

- **Input validation** - URL schemes (reject `file://`, `javascript://`), paths (no directory traversal), JSON (malformed + deeply nested), env vars (empty handling)
- **Authentication** - bearer tokens over HTTPS only, no token echo in logs, no token in `ps aux` (prefer env vars), per-server token scoping
- **TLS** - no cert skipping, no insecure fallback
- **Resource limits** - response size cap (no OOM from malicious server), timeouts, concurrent request caps
- **Injection risks** - shell (unquoted `$(...)`), HTTP header (CRLF), JSON-in-string, path
- **Secrets leakage** - `--debug` logs, error messages, crash dumps, test fixtures
- **Secure by default** - opt-in for dangerous features, loud warnings, conservative defaults
- **Concurrency** - `@unchecked Sendable` needs proof of thread safety, actor isolation correct, no missing locks
- **Supply chain** - new dependencies pinned, scope justified, no transitive `unsafeFlags`

Priority-rank findings:
- **P0** blocks merge (security, data loss, credential leak, regression to previous fix)
- **P1** should fix before merge (correctness, test coverage, architectural consistency)
- **P2** nice to have (code quality, follow-up PR acceptable)

### 6. Architecture review

- Does it fit the golden goal (UNIX tool + OpenAI server + chat)?
- Does it respect the non-negotiable principles (100% on-device, honest limits, clean code, Swift 6 strict concurrency, usable security)?
- Does it introduce cross-target dependencies that violate the `ApfelCore` (pure) / `ApfelCLI` (CLI types) / `apfel` (FoundationModels + Hummingbird) layering?
- Are the existing patterns followed (test harness, error types, context strategy, retry)?

### 7. Test coverage check (code PRs)

- New flag? Must have happy-path + every validation error test in `Tests/apfelTests/CLIArgumentsTests.swift`
- New public API on a pure `ApfelCore` type? Unit test in the corresponding `Tests/apfelTests/*Tests.swift`
- New network or subprocess surface? Integration test wired into `Tests/integration/` using the existing conftest pattern - **standalone manual scripts in `mcp/`, `scripts/`, etc. do not count**
- Error tests must use the tightened style: `catch let e as CLIParseError { assertTrue(e.message.contains("...")) }` - not just `threw = true`

### 8. Build + run tests on the PR branch

```bash
git checkout pr-<n>-head
swift build                                              # must be clean, no warnings
swift run apfel-tests                                    # existing unit tests must still pass
# For code PRs, also:
make install && apfel --serve --port 11434 &
apfel --serve --port 11435 --mcp mcp/calculator/server.py &
sleep 4
python3 -m pytest Tests/integration/ -v                  # must pass, 0 skipped
pkill -f "apfel --serve"
```

### 9. Verify CI on the PR

- `gh pr view <n> --repo Arthur-Ficial/apfel --json statusCheckRollup`
- First-time contributors trigger `action_required` on Actions - the CI run needs manual approval before it executes. Approve it before reviewing so the PR has real CI results to reference.

### 10. Review

Post a structured review via `gh pr review <n> --repo Arthur-Ficial/apfel --request-changes|--approve|--comment --body "..."`:

- **Open with genuine praise** for what works. Reviews that lead with negatives make contributors defensive.
- **Summary table** of findings (P0/P1/P2, severity, area, one-line summary)
- **Each finding** gets its own subsection: exact file:line reference, reproducer where possible, concrete fix with code sample
- **What I verified** section listing what's clean (shows the contributor you actually read everything)
- **Suggested path forward** ranked by minimum-viable-merge vs full fix
- **Credit co-authors** - when landing, use `Co-Authored-By: <Name> <email>` in the merge commit

Do not approve code PRs with P0 findings. For docs-only PRs, a request-changes on a broken link is appropriate. For first-time contributors, err on the side of gentler tone.

### 11. Merge decision

- **Approve + merge** only after: all P0/P1 resolved (or explicitly punted with user's OK), CI green, tests green on the branch locally
- **Squash-merge** by default for clean history. Preserve the contributor's commit messages in the squash body so attribution is intact.
- **Do not release** just because you merged. A merge and a release are separate user decisions - ask first.
- **Close linked issues** via `Closes #N` in the PR body or commit message, otherwise do it manually after merge.

### 12. After merge

- Verify main locally: `git checkout main && git pull --rebase origin main`
- Run the full test suite on the merged commit as a sanity check
- If any follow-up is needed (P2 items punted, new issues surfaced), file them as GitHub issues before moving on
- **Clean up the local PR branch**: `git branch -D pr-<n>-head`

### PR anti-patterns to reject

- No tests for new flags or new behavior
- Standalone test scripts that require manual terminal orchestration (not wired into CI)
- `@unchecked Sendable` without explicit thread-safety proof
- `URLSession.shared` for new network code (shared cookie jar, shared cache)
- Bearer tokens sent over `http://`
- New `exit()` calls in pure parsing functions
- Manual edits to `.version`, `README.md` version badge, or `Sources/BuildInfo.swift` (these are release workflow outputs)
- Merge commits in the PR branch history (prefer rebase and squash)
- Contributor working from their fork's `main` branch instead of a feature branch (cosmetic, but harder to land cleanly)

## Publishing a Release

**MANDATORY: always use the automated workflow.** No manual releases. No exceptions.

### Before releasing

```bash
make preflight
```

This runs the full qualification locally: clean git state, on main, unit tests, integration tests (7 suites), policy file checks, version sanity. **Do not release if preflight fails.**

### Release

```bash
make release                    # patch (1.0.0 -> 1.0.1)
make release TYPE=minor         # minor (1.0.x -> 1.1.0)
make release TYPE=major         # major (1.x.y -> 2.0.0)
```

This runs locally (not on GitHub Actions - GitHub runners lack Apple Intelligence). The script (`scripts/publish-release.sh`) does everything:

1. Preflight checks (clean tree, on main, up to date with origin)
2. Bumps `.version` (patch/minor/major)
3. Builds the release binary
4. Runs ALL unit tests (362+)
5. Runs ALL 7 integration test suites with real Apple Intelligence (cli_e2e, performance, openai_client, openapi_spec, security, mcp_server, openapi_conformance)
6. Commits `.version`, `README.md`, `Sources/BuildInfo.swift` and pushes to `main`
7. Creates git tag (`v<version>`) and pushes it
8. Packages tarball and publishes GitHub Release with changelog
9. Updates the Homebrew tap formula

### After releasing

```bash
./scripts/post-release-verify.sh
```

Verifies: GitHub Release exists with tarball, git tag exists, `.version` matches, installed binary matches.

### Distribution channels

apfel ships through three channels. All pull the same signed tarball from each GitHub Release.

- **homebrew-core** — `brew install apfel`. Autobump detects new releases; latency ~24h. We do not maintain the formula.
- **Arthur-Ficial/homebrew-tap** — `brew install Arthur-Ficial/tap/apfel`. Synchronous, pushed as part of `make release`. Secondary channel; also houses apfel-family tools (apfel-chat, apfel-clip, apfel-mcp, etc.).
- **nixpkgs** — `nix profile install nixpkgs#apfel-ai`. Name is `apfel-ai` because nixpkgs already has an unrelated physics `apfel`. Two-layer automation: community r-ryantm bot (~weekly) plus our `.github/workflows/bump-nixpkgs.yml` on every release (~5 min). See [docs/nixpkgs.md](docs/nixpkgs.md). Requires the `NIXPKGS_BUMP_PAT` repo secret.
- Emergency Homebrew bump: `brew bump-formula-pr apfel --url=<tarball-url> --sha256=<hash>`
- Emergency nixpkgs bump: run `scripts/bump-nixpkgs.sh` against a local nixpkgs clone and open a PR manually.

### Do NOT manually

- Run `bump-patch`, `bump-minor`, `bump-major` directly
- Edit `.version`, `BuildInfo.swift`, or README badge
- Create git tags or run `gh release create`
- Push to the Homebrew tap manually (the workflow handles it)

### Integration test rules

- **Never skip tests.** A skipped test is a critical error.
- Integration tests require two running servers: port 11434 (plain) and port 11435 (with MCP calculator).
- If servers aren't running, tests skip silently - this is NOT acceptable. Always start them.

### Post-release checklist

- [ ] `make preflight` passed before release
- [ ] Publish Release workflow completed green
- [ ] `./scripts/post-release-verify.sh` passed
- [ ] CLAUDE.md version and test counts updated (if changed)
- [ ] File a ticket on `Arthur-Ficial/apfel-web` if the landing page needs update

## CI / GitHub Actions

**IMPORTANT: GitHub CI runs only a SUBSET of tests.** GitHub-hosted `macos-26` runners are Intel Macs with no Apple Intelligence. Most integration tests need the model and cannot run there.

**What GitHub CI runs (automatic, every push/PR):**
- Build (release binary)
- 366 unit tests (pure Swift, no model needed)
- 21 model-free integration tests (CLI flags, help, version, file handling)
- Total: ~387 tests

**What GitHub CI CANNOT run (no Apple Intelligence):**
- Server response tests (openai_client, openapi_spec, openapi_conformance)
- MCP tool execution tests (mcp_server, mcp_remote)
- Security tests that send real requests (security)
- Benchmark tests (performance)
- Chat mode tests (test_chat)
- Brew service tests (test_brew_service)
- Total: ~199 integration tests

**What runs the full suite (local, before every release):**
- `make preflight` or `make release` on a Mac with Apple Intelligence
- 366 unit + 220 integration (10 suites) = 586 tests, 0 skipped
- Release scripts use directory discovery (`Tests/integration/`), not explicit file lists
- This is the REAL qualification gate. GitHub CI is a safety net, not the source of truth.

SDK 26.4+ required for FoundationModels token-counting APIs. Release docs: [docs/release.md](docs/release.md)
