# Local Setup with Visual Studio Code

The shape of the setup is:

1. Run `apfel --serve` as a local OpenAI-compatible server.
2. Use the Continue extension in Visual Studio Code.
3. Route **chat/code review** to local `apfel`.
4. Route **edit/apply** to a second model.
5. Keep `~/.continue/.env` in sync from the shell so Continue can read `OPENAI_API_KEY`.

For the underlying API contract, see [docs/openai-sdk.md](docs/openai-sdk.md) and [docs/server-security.md](docs/server-security.md).

## 1. Start `apfel` as the local server

Use `apfel` as the local OpenAI-compatible base URL:

```text
http://127.0.0.1:11434/v1
```

Start it in the foreground:

```bash
apfel --serve
```

Or run it in the background:

```bash
brew services start apfel
```

Background-service details: [docs/background-service.md](docs/background-service.md)

Important: use **Chat Completions**, not the newer Responses API. `apfel` supports `POST /v1/chat/completions` and does not implement `POST /v1/responses`. See [docs/openai-sdk.md](docs/openai-sdk.md).

## 2. Install the Continue extension in Visual Studio Code

Use Continue as the Visual Studio Code front end.

Continue reads configuration from:

- `~/.continue/config.yaml`
- `~/.continue/.env`

## 3. Configure Continue with two models

Use local `apfel` for safer chat/review work and a second model for edit/apply.

Create or replace `~/.continue/config.yaml` with:

```yaml
name: Apfel Review + OpenAI Apply
version: 0.0.1
schema: v1

models:
  - name: apfel-review
    provider: openai
    model: apple-foundationmodel
    apiBase: http://127.0.0.1:11434/v1
    apiKey: ignored
    roles:
      - chat
    defaultCompletionOptions:
      contextLength: 4096
      temperature: 0.0
      maxTokens: 450
    chatOptions:
      baseSystemMessage: |
        You are a code review assistant.
        Prioritize correctness, regressions, edge cases, security risks, performance risks, and missing tests.
        Review only the provided diff, file, or selection.
        Give findings first, ordered by severity.
        Be concrete and cite exact lines, symbols, or behaviors when possible.
        Do not rewrite code unless explicitly asked.
        If evidence is insufficient, say what needs verification.

  - name: gpt-5.1-apply
    provider: openai
    model: gpt-5.1
    apiKey: ${{ secrets.OPENAI_API_KEY }}
    roles:
      - edit
      - apply
    defaultCompletionOptions:
      temperature: 0.0
      maxTokens: 1200

context:
  - provider: diff
  - provider: file

rules:
  - Keep reviews concise, evidence-based, and skeptical.
  - Prefer bugs, regressions, security issues, and missing tests over style nits.
  - If no findings are clear, say that explicitly and list residual risks.
  - If editing, preserve behavior unless the user explicitly requests a refactor.
  - Do not expand scope beyond the selected file, diff, or instruction.
```

Why this split works:

- `apfel-review` is restricted to `chat`, so it becomes the local review lane.
- `gpt-5.1-apply` handles `edit` and `apply`, where a stronger hosted model is more useful.
- `temperature: 0.0` keeps both lanes deterministic.
- `contextLength: 4096` matches `apfel`'s local context budget.

## 4. Provide `OPENAI_API_KEY` to Continue

Continue reads secrets from `~/.continue/.env`.

The direct manual version is:

```dotenv
OPENAI_API_KEY=your_openai_api_key_here
```

But in our setup, we also wired this into the shell so Continue's `.env` file is updated automatically from the existing Codex login helpers in `~/.zshrc`. (See: [Leveraging multiple, repository-specific OpenAI Codex API Keys with Visual Studio Code on macOS](https://snelson.us/2026/04/many-to-one-api-keys/).)

## 5. Sync `~/.continue/.env` automatically from `~/.zshrc`

Inside the `# --- OpenAI Codex: Start` / `# --- OpenAI Codex: End` block in `~/.zshrc`, we added helpers so that:

- `cli` logs Codex in and writes `OPENAI_API_KEY=...` to `~/.continue/.env`
- `clo` logs Codex out and removes only the `OPENAI_API_KEY` line from `~/.continue/.env`

That means your typical flow becomes:

```bash
source ~/.zshrc
cli
```

When you are done with the Visual Studio Code session:

```bash
clo
```

This keeps the Continue secret in step with the rest of your Codex/OpenAI shell workflow without requiring manual edits to `~/.continue/.env` each time.

## 6. Restart Visual Studio Code after auth changes

After changing auth state, reload Visual Studio Code's extension host so Continue picks up the current environment and config.

Use:

```text
Cmd + Shift + P -> Developer: Restart Extension Host
```

## 7. Recommended day-to-day usage

Use local `apfel` for:

- review the current diff
- review the selected function
- summarize a file before editing
- identify likely regressions
- point out missing tests

Use the hosted edit/apply model for:

- targeted code changes
- apply/fix flows
- rewriting a selected block
- generating a patch after review findings are clear

This is the important habit: keep `apfel` focused on **small review contexts**. It works best on a diff, one file, or one selected region, not giant repo-wide prompts.

## 8. Typical workflow

1. Start `apfel` with `apfel --serve` or `brew services start apfel`.
2. Open Visual Studio Code.
3. Run `cli` in your shell to authenticate Codex and update `~/.continue/.env`.
4. Restart the Visual Studio Code extension host.
5. Ask Continue chat to review the current diff or selected code using the local `apfel-review` model.
6. Once the review is clear, use Edit/Apply to hand the actual code change to the hosted `gpt-5.1-apply` model.
7. Run `clo` when you are done to clear the shell key and remove `OPENAI_API_KEY` from `~/.continue/.env`.

## 9. Troubleshooting

If Continue cannot talk to local `apfel`:

- make sure `apfel --serve` is running
- confirm the base URL is `http://127.0.0.1:11434/v1`
- confirm the model name is `apple-foundationmodel`
- make sure the client is using Chat Completions, not Responses

If Continue cannot use the hosted edit/apply model:

- check that `~/.continue/.env` contains `OPENAI_API_KEY=...`
- run `cli` again after reloading `~/.zshrc`
- restart the Visual Studio Code extension host

If you need a browser client instead of Continue:

- use `apfel --serve --cors --allowed-origins "<your local origin>"`

For security and browser details, see [docs/server-security.md](docs/server-security.md).
