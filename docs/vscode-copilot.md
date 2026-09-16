# VSCode Copilot BYOK with apfel

VSCode Copilot can use apfel as a **custom chat model** via its [BYOK custom-endpoint support](https://code.visualstudio.com/docs/copilot/customization/language-models#_add-a-custom-endpoint-model). apfel's `/v1/chat/completions` is OpenAI-compatible (streaming SSE with a leading `role` delta and a terminating `data: [DONE]`), so chat works.

## Start the server

```bash
apfel --serve
```

## Copilot configuration

The on-device window is **input and output combined**, not one budget each, and apfel reserves 512
tokens for the response by default (`--context-output-reserve`). So `maxInputTokens` and
`maxOutputTokens` have to *sum* to the window - setting both to the full window asks for twice what
exists. Run `apfel --model-info` to see your window, then use the matching block below.

On **macOS 26** (4096-token window), add this to your VSCode settings:

```json
[
  {
    "name": "Apfel",
    "vendor": "customendpoint",
    "apiType": "chat-completions",
    "models": [
      {
        "id": "apple-foundationmodel",
        "name": "Apple Foundation Model",
        "url": "http://127.0.0.1:11434/v1/chat/completions",
        "toolCalling": false,
        "vision": false,
        "maxInputTokens": 3584,
        "maxOutputTokens": 512
      }
    ]
  }
]
```

On **macOS 27** (8192-token window), use this instead:

```json
[
  {
    "name": "Apfel",
    "vendor": "customendpoint",
    "apiType": "chat-completions",
    "models": [
      {
        "id": "apple-foundationmodel",
        "name": "Apple Foundation Model",
        "url": "http://127.0.0.1:11434/v1/chat/completions",
        "toolCalling": false,
        "vision": false,
        "maxInputTokens": 7680,
        "maxOutputTokens": 512
      }
    ]
  }
]
```

If you raise `maxOutputTokens`, lower `maxInputTokens` by the same amount and raise apfel's reserve
to match (`apfel --serve --context-output-reserve <n>`), so the two sides still agree on the split.

Select **Apple Foundation Model** in the Copilot Chat model picker. Chat requests are served on-device.

## Diagnosing problems

Run the server with debug logging to see every request and response apfel receives (added in 1.5.0):

```bash
APFEL_DEBUG=1 apfel --serve
```

Equivalently, pass the `--debug` flag. This prints the raw request body and the response, which is the fastest way to see what a client is actually sending.

## Known limitation: inline / edit completions are not supported

Copilot's **inline code completion** (and edit predictions) is a fill-in-the-middle (FIM) flow, not a chat flow. The Apple on-device Foundation model has no FIM capability, and apfel returns an honest `501` for the legacy completions endpoint. If you configure apfel as a *completion* model you will see a client-side `AbortError` / `ABORT_ERR` when Copilot gives up on the unsupported request - this is expected, not an apfel bug.

Use apfel as a **chat** model only. (The same applies to other editors - e.g. Zed's chat works, but its legacy `edit_predictions` FIM endpoint cannot.)
