# apfel Integrations

Community-contributed configurations for using apfel with other tools.

---

## opencode

[opencode](https://opencode.ai) is an open-source terminal AI coding assistant. You can wire it to apfel's OpenAI-compatible server so all inference stays on-device at zero cost.

**Config:** `~/.config/opencode/opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": true,
  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 512
  },
  "default_agent": "lean",
  "agent": {
    "lean": {
      "mode": "primary",
      "model": "apfel/apple-foundationmodel",
      "prompt": "You are a concise assistant. Answer directly.",
      "permission": {
        "*": "deny"
      }
    }
  },
  "provider": {
    "apfel": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "apfel",
      "options": {
        "baseURL": "http://127.0.0.1:11434/v1"
      },
      "models": {
        "apple-foundationmodel": {
          "name": "apple-foundationmodel"
        }
      }
    }
  }
}
```

**Start apfel first:**

```bash
apfel --serve
```

**Why this config works the way it does:**

- `default_agent: "lean"` - the lean agent has `"permission": { "*": "deny" }`, which means opencode won't try to inject tool schemas. This matters because apfel has a 4096-token context window - tool schemas eat into it fast.
- `compaction.reserved: 512` - reserves 512 tokens for output. Keeps the model from running out of room mid-answer.
- `"npm": "@ai-sdk/openai-compatible"` - opencode's provider system. This package speaks the OpenAI REST protocol, which apfel implements at `/v1/chat/completions`.
- `baseURL: "http://127.0.0.1:11434/v1"` - apfel's default port and path.

**Result:** $0.00/request, fully on-device, 1-2s response times.

![opencode using apple-foundationmodel via apfel](../screenshots/opencode-integration.png)

*opencode 1.3.17, answering from the `lean` agent backed by `apple-foundationmodel` via apfel. Context: 1,181 tokens, $0.00 spent.*

---

Huge thanks to [**@tvi** (Tomas Virgl)](https://github.com/tvi) for contributing this integration and for taking the time to provide a working config and a real screenshot. This is exactly the kind of community contribution that makes apfel more useful.

---

## Visual Studio Code + Continue

Use `apfel` as the local review/chat model in Visual Studio Code and pair it with a second model for Edit/Apply. (See also: [Leveraging multiple, repository-specific OpenAI Codex API Keys with Visual Studio Code on macOS](https://snelson.us/2026/04/many-to-one-api-keys/).)

Step-by-step setup: [local-setup-with-vs-code.md](local-setup-with-vs-code.md)

Why this setup works well:

- `apfel` stays in the small-context, low-latency review lane
- Continue provides the Visual Studio Code integration
- a second model can handle larger edit/apply tasks without overloading `apfel`'s 4096-token context window

---

*Have an integration to share? Open an issue at [https://github.com/Arthur-Ficial/apfel/issues](https://github.com/Arthur-Ficial/apfel/issues).*
