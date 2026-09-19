# apfel Integrations

Community-contributed configurations for using apfel with other tools.

For **scripting language guides** (how to call apfel from Python, Node.js, Ruby, PHP, Bash, Zsh, AppleScript, Swift, Perl, AWK) see [docs/guides/index.md](guides/index.md). Every snippet there was run against a live apfel server; lab repo: [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

---

## opencode

[opencode](https://opencode.ai) is an open-source terminal AI coding agent. Wire it to apfel's OpenAI-compatible server and every token stays on-device at zero cost. Re-verified end-to-end on opencode 1.17.16 + apfel 1.8.2.

Full setup, the verified config, a real transcript, and every gotcha are on the dedicated page: [docs/integrations/opencode.md](integrations/opencode.md). The one you must not miss: opencode pastes your global `~/.claude/CLAUDE.md` into the system prompt, which overflows apfel's on-device context window (4096 tokens on macOS 26, 8192 on macOS 27) - fix it with `export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1`.

---

## Zed

[Zed](https://zed.dev)'s agent panel works with apfel via the chat-completions provider. On-device, no key.

**Heads-up:** use `language_models.openai_compatible` (chat). Do **not** use `edit_predictions.open_ai_compatible_api` - that's a legacy text-completions endpoint apfel deliberately doesn't support.

**Config:** `~/.config/zed/settings.json`

```json
{
  "language_models": {
    "openai_compatible": {
      "Apfel": {
        "api_url": "http://127.0.0.1:11434/v1",
        "available_models": [
          {
            "name": "apple-foundationmodel",
            "display_name": "Apfel (apple on-device)",
            "max_tokens": 4096,
            "max_output_tokens": 1024,
            "capabilities": { "tools": true, "images": false, "parallel_tool_calls": false, "prompt_cache_key": false }
          }
        ]
      }
    }
  }
}
```

`max_tokens` is the context window, covering input and output combined. `4096` is the **macOS 26** value; on **macOS 27** set `max_tokens: 8192`, or you give up half the window. `apfel --model-info` prints the live value for your machine.

Start apfel:

```bash
apfel --serve
```

Launch Zed (Zed insists on a key for the provider; apfel ignores it):

```bash
APFEL_API_KEY=dummy zed
```

Open the agent panel (`Cmd+?`), pick `Apfel (apple on-device)`, send a prompt. Zed POSTs to `/v1/chat/completions` on apfel.

---

## Visual Studio Code + Continue

Use `apfel` as the local review/chat model in Visual Studio Code and pair it with a second model for Edit/Apply. (See also: [Leveraging multiple, repository-specific OpenAI Codex API Keys with Visual Studio Code on macOS](https://snelson.us/2026/04/many-to-one-api-keys/).)

Step-by-step setup: [local-setup-with-vs-code.md](local-setup-with-vs-code.md)

Why this setup works well:

- `apfel` stays in the small-context, low-latency review lane
- Continue provides the Visual Studio Code integration
- a second model can handle larger edit/apply tasks without overloading `apfel`'s small on-device context window (4096 tokens on macOS 26, 8192 on macOS 27)

---

*Have an integration to share? Open an issue at [https://github.com/Arthur-Ficial/apfel/issues](https://github.com/Arthur-Ficial/apfel/issues).*
