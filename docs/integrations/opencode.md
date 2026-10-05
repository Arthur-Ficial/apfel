# apfel + opencode

Run [opencode](https://opencode.ai), the open-source terminal AI coding agent, against apfel's OpenAI-compatible server so every token stays on-device at zero cost.

**Verified:** opencode 1.17.16 + apfel 1.8.2, macOS 26 (Apple Silicon). A real session transcript is at the bottom of this page.

## 0. Install opencode

Use the official installer - it fetches the platform binary to `~/.opencode/bin/opencode`:

```bash
curl -fsSL https://opencode.ai/install | bash
```

Then ensure `~/.opencode/bin` is on your `PATH`.

> Gotcha: `npm install -g opencode-ai` on its own may not produce a working `opencode` command, because the package's post-install download is skipped under npm's `allow-scripts` policy. The `curl` installer above avoids that.

## 1. Start apfel

```bash
apfel --serve
```

This serves the OpenAI API at `http://127.0.0.1:11434/v1`. Confirm it is up:

```bash
curl -s http://127.0.0.1:11434/v1/models
```

## 2. Configure opencode

Write this to `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "compaction": { "auto": true, "prune": true, "reserved": 512 },
  "default_agent": "lean",
  "agent": {
    "lean": {
      "mode": "primary",
      "model": "apfel/apple-foundationmodel",
      "prompt": "You are a concise assistant. Answer directly.",
      "permission": { "*": "deny" }
    }
  },
  "provider": {
    "apfel": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "apfel",
      "options": {
        "baseURL": "http://127.0.0.1:11434/v1",
        "apiKey": "not-needed"
      },
      "models": {
        "apple-foundationmodel": { "name": "apple-foundationmodel" }
      }
    }
  }
}
```

The model id `apple-foundationmodel` must match exactly what apfel reports at `/v1/models`. `apiKey` is a placeholder: a local apfel server started without `--serve-token` needs no auth, but opencode's OpenAI-compatible provider still wants the field present.

## 3. Run it

One-shot (note the env var - see [the 4096-token fix](#the-4096-token-window-the-fix-you-must-set) below):

```bash
OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1 opencode run --agent lean "In one sentence, what is a hash map?"
```

Interactive:

```bash
OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1 opencode
```

Set that variable once in your shell profile (`~/.zshrc`) so you never forget it:

```bash
echo 'export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1' >> ~/.zshrc
```

## The 4096-token window: the fix you must set

apfel's on-device model has a **4096-token context window** on macOS 26 and on M1/M2 Macs (8192 on macOS 27 with an M3 or newer chip and 12 GB+; apfel reads the real size at runtime, check `apfel --model-info`). Everything on this page was measured on macOS 26 and the failure mode is identical on macOS 27, with more headroom on an 8192 machine. opencode is a full coding agent, and it **injects your instruction files into the system prompt on every request**. It loads them in this order (each category accumulates - they do not replace each other):

1. Local `AGENTS.md` / `CLAUDE.md` (walking up from the current directory)
2. Global `~/.config/opencode/AGENTS.md`
3. Claude Code fallback: **`~/.claude/CLAUDE.md`**

That third one is the trap. opencode has undocumented Claude Code compatibility: if you use Claude Code, your global `~/.claude/CLAUDE.md` gets pasted into opencode's system prompt verbatim. A big one (this machine's was ~12 KB / ~3,300 tokens) fills the 4096-token window before you type a word, and apfel returns an honest HTTP 400:

```
Error: Input exceeds the model's context window. Shorten the conversation history.
```

### The fix: disable the Claude Code prompt

Set this environment variable. It tells opencode to stop loading `~/.claude/CLAUDE.md`:

```bash
export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1
```

Proven on this machine, with the 12 KB `~/.claude/CLAUDE.md` left in place:

| | Request to apfel | Result |
|---|---|---|
| Without the var | 13,461 bytes | **400 - context overflow** |
| `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1` | 2,498 bytes | **200 OK, real answer** |

The `instructions` field in `opencode.json` does **not** help here - it *adds* files, it cannot remove the auto-loaded `CLAUDE.md`. The env var is the fix. (To drop all Claude Code compatibility, not just the prompt, use `OPENCODE_DISABLE_CLAUDE_CODE=1`.)

### Then keep the rest of the payload small

With `CLAUDE.md` out of the way, two things in the config above keep you comfortably inside 4096 tokens:

- `"permission": { "*": "deny" }` on the `lean` agent stops opencode sending tool schemas (they eat the window fast).
- A short custom `"prompt"` replaces opencode's default agent instructions.

Also keep any **project** `AGENTS.md` small - it loads too, and the env var does not touch it.

Because of that window, apfel is a great opencode backend for **short Q&A and small, focused edits** - not for large-repo, many-tool, long-running agent sessions. That is a property of the on-device model, not the wiring. The `apfel --count-tokens` flag (see [docs/cli-reference.md](../cli-reference.md)) preflights how much a prompt will cost against the window.

## All the gotchas (from re-verifying this end-to-end)

Every one of these was hit and confirmed while testing on 2026-07-09:

1. **Install**: `npm install -g opencode-ai` can leave you with no working binary (post-install script skipped by npm `allow-scripts`). Use the `curl` installer; the binary lands at `~/.opencode/bin/opencode`.
2. **The 4096-token window is the whole story, and global `~/.claude/CLAUDE.md` is the usual killer.** opencode pastes `AGENTS.md`, local `CLAUDE.md`, and (undocumented Claude Code compatibility) global `~/.claude/CLAUDE.md` into the system prompt. A large global `CLAUDE.md` alone (~12 KB / ~3,300 tokens here) overflows the window before you type anything - HTTP 400. **Fix: `export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1`** - proven to drop the request from 13,461 to 2,498 bytes (400 to 200). The `instructions` config field cannot remove it; only the env var does.
3. **Deny tools.** `"permission": { "*": "deny" }` stops opencode sending tool schemas, which otherwise consume a big slice of the 4096 tokens.
4. **Set a short agent `prompt`.** It replaces opencode's default agent instructions (verified: the custom prompt does take effect); without it the default coding-agent preamble is larger.
5. **`apiKey` must be present** in the provider `options` even though a local apfel server needs no auth - opencode's `@ai-sdk/openai-compatible` provider expects the field. Any placeholder works.
6. **Model id must match `/v1/models` exactly** (`apple-foundationmodel`). A mismatch fails the request.
7. **opencode makes two calls per turn**: a small title-generation call (always fits) plus the main agent call (the one that can overflow). Seeing the title call succeed but the answer fail is the classic 4096-overflow signature.
8. **`--pure` does not help the overflow** - it disables plugins, not instruction-file ingestion.
9. **Restart opencode after config changes** - it does not always hot-reload provider config.

## Verified session

apfel 1.8.2 server, opencode 1.17.16, `lean` agent, with a 12 KB global `~/.claude/CLAUDE.md` present (the fix env var set):

```
$ OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1 opencode run --agent lean \
    "In one sentence, what is a binary search?"
> lean · apple-foundationmodel

A binary search is an efficient algorithm for finding an item from a sorted
array of items, by repeatedly dividing the search interval in half.
```

apfel's request log for that turn - every call `200 OK`, well inside the window, `$0.00`:

```
POST /v1/chat/completions 200 67ms stream tokens=~591   request bytes=2498
POST /v1/chat/completions 200 44ms stream tokens=~198   request bytes=713
```

Without `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1`, the same turn sent 13,461 bytes and apfel returned `400 - Input exceeds the model's context window`.

## Credit

The original config and the first working screenshot came from [@tvi (Tomas Virgl)](https://github.com/tvi). This page adds an end-to-end re-verification on current opencode and the 4096-token instruction-file gotcha.
