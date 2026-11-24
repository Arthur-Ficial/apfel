# apfel Tool Calling Guide

Real findings from systematic experimentation with Apple's on-device FoundationModels LLM
and apfel's OpenAI-compatible tool calling implementation.

**Findings from:** 2026-03-26 (apfel v0.5.0, macOS 26.3) | **Last verified:** 2026-07-02 (apfel v1.7.1, macOS 26.5.2). The documented behaviors are exercised by the MCP integration suites (`Tests/integration/mcp_server_test.py`, `Tests/integration/mcp_remote_test.py`) on every release.

> **Looking for ready-made MCPs?** [apfel-mcp.franzai.com](https://apfel-mcp.franzai.com/) ships three token-budget-optimized MCP servers designed for apfel's small on-device context window (4096 tokens on macOS 26 and on M1/M2 Macs, 8192 on macOS 27 with an M3 or newer chip and 12 GB+ (Apple's AFM 3 Core Advanced model)): `url-fetch`, `ddg-search`, and the flagship compound `search-and-fetch` tool. `brew install Arthur-Ficial/tap/apfel-mcp`. The repo is open for contributions of new apfel-optimized MCPs - see [apfel-mcp.franzai.com/#contribute](https://apfel-mcp.franzai.com/#contribute).

> **Managing many MCPs?** [Arthur-Ficial/apfel-run](https://github.com/Arthur-Ficial/apfel-run) is an MIT wrapper that keeps an enabled/disabled list in `~/.config/apfel/mcps.conf` (comment out with `-` to disable), builds `APFEL_MCP`, and `execve`s apfel. Stop typing `--mcp` on every call; edit the file instead.

> **Preflight your token budget:** MCP tool schemas consume context fast. Run `apfel --count-tokens --mcp ./server.py "prompt"` before attaching tools in scripts or integrations. See [cli-reference.md](cli-reference.md).

---

> Note on the `usage` numbers in the examples below: they come from macOS 26's counted path. On macOS 27 the runtime reports its own accounting, which includes Apple's chat-template framing (about 46 extra `prompt_tokens`) and prices tool definitions as the model receives them, so the figures are higher there. See [docs/openai-api-compatibility.md](openai-api-compatibility.md).

## How It Works

apfel describes every OpenAI-format tool to the model in its instructions, as a
plain-language list (#555, #581):

```
Available functions:
- add: Add two numbers. Arguments: a (number, required); b (number, required)
- search: Search the web. Arguments: query (string, required, min length 1): what to find; limit (integer, default 10, minimum 1)
- tag: Tag a file. Arguments: tags (array, required): labels [schema: {"items":{"type":"string"}}]
```

Scalar arguments are written as `name (type, required, constraints): description`;
simple constraints (`default`, `minimum`, `maxLength`, ...) are words, annotation-only
keys (`title`, `examples`) are left out, and nested structure (array items, objects,
unions) is kept as compact JSON in brackets so it cannot read as one more argument.
apfel never runs client tools: it returns the call as OpenAI `tool_calls` and the
client executes it (#119).

### The guided tool step (default since 1.19.0, `--tool-calling guided`)

For `/v1/chat/completions` requests with client `tools`, the model does not write the
call as free text. Its decision is generated under a JSON schema (#533):

```
{"action": "<one of the tool names, or answer>",
 "arguments": {"<tool name>": {<that tool's parameters>}}}
```

- A tool action becomes a normal `tool_calls` response. Argument names come from the
  tool's schema, so the model cannot invent keys, break the escaping or drop required
  arguments. If it leaves the chosen tool's arguments out, one more guided request in the
  same session writes them under that tool's own schema; the result is still checked
  against the original schema.
- `answer` means: reply in plain text. That reply is written by a second, ordinary
  request without tool instructions, so it streams as usual and the tool list cannot
  bend it. Its `usage` includes the decision step.
- `tool_choice: "required"` removes `answer` from the choices; a named function leaves
  only that function.
- Schema keywords guided generation cannot enforce (`minLength`, `pattern`,
  `multipleOf`, ...) are dropped from the step's copy of the schema, not from the check.
  A tool whose parameters guided generation cannot express at all (a map with
  schema-valued `additionalProperties` or `patternProperties`, a root `$ref` or union)
  makes the request use the free-text format below; `--debug` logs why.
- `max_tokens` caps the answer, not the decision step or a call's arguments.
- The step's schema and tool list cost context the free-text format does not. When the
  step does not fit the window, the request uses the free-text format below instead of
  failing (#590); only a request that free text cannot fit either gets the 400
  `context_length_exceeded`. `--debug` logs the fallback.
- Not covered yet: tools attached with `--mcp` (auto-executed), `/v1/responses`, and the
  CLI use the free-text format.

Measured 2026-11-17 with the tool sets from #580/#581 (time tools, web search/fetch,
calculator, a location + weather pair), 20 runs per prompt, streamed and non-streamed,
same binary in both modes. A run counts as good when the reply is a call to the right
tool with arguments that match its schema, or a plain answer where no tool is needed:

| | `--tool-calling guided` | `--tool-calling text` |
|---|---|---|
| macOS 27.0.1, M2 (AFM 3 Core) | **360/360** | 231/360 |
| macOS 26.1, M5 (AFM 2 Core) | **241/360** | 183/360 |

Where text loses: escaping and argument errors (`series`, and on macOS 26.1 the
calculator 4/80), and tool calls for prompts that need none (`hello`, a short story).
Where guided lost on macOS 26.1: the older model picked a tool for a greeting or a story
(hello 16/40 vs 40/40 in text mode, story 0/40 vs 27/40). Since two examples that answer
were added to the decision text (#590, re-measured 2026-11-24, 20 runs per prompt,
streamed and non-streamed, same day for both binaries), guided on macOS 26.1 went from
254/360 to 292/360: hello 23/40 to 40/40, story 3/40 to 19/40, no prompt worse; macOS
27.0.1 stayed at 360/360. Still weak on macOS 26.1: stories (19/40), and "What's the
weather where I am?" calls `get_weather` with made-up coordinates instead of
`get_current_location` (0/40, also before the change). Use `--tool-calling text` if
that matters more to you than correct calls. Cost: an answer
takes one extra request (on macOS 27, e.g. 2.3 s for "Hello" with six tools in scope);
a call is usually one request, and often faster than the free-text envelope (web search
on macOS 27: 2.8 s vs 5.0 s) because only the arguments are generated. The table was
measured before the step schema dropped its duplicated descriptions (about 20% fewer
tokens); six of the prompts were re-run on both OSes after that change.

### The free-text format (`--tool-calling text`)

The model is told to answer a call with a specific JSON envelope, which apfel detects
post-hoc via `ToolCallHandler.detectToolCall()`. Detection handles clean JSON,
markdown-wrapped ```` ```json ``` ```` blocks, JSON after preamble text, and the variant
shapes the model writes (name under `type`, `function_name` or `name`, arguments as
sibling keys, #580). Calls are then held to the tool's schema (see the next section).

Why text and not FoundationModels' `Transcript.ToolDefinition`: the macOS 26 and 27
runtimes ignore transcript-only tool definitions when no tool is registered with the
session, so the model only ever saw the tool names (measured: correct argument names
0/10 with definitions, 10/10 with the list). A list rather than JSON schema text,
because on macOS 26.1 JSON schema text made Apple's guardrail block a plain
arithmetic question with the calculator tools, and the list is cheaper.

## `tool_choice` and `parallel_tool_calls` are enforced

The model is steered towards the requested `tool_choice` with prompt instructions, but a small
on-device model does not always comply, so apfel also holds every response to the contract
before it reaches the client or an MCP server (#480):

| Request | Before generation | Model output that breaks the contract |
|---------|-------------------|----------------------------------------|
| `tool_choice: "none"` | No tools are presented, MCP tools are not auto-executed | Tool-call-shaped JSON is delivered as ordinary `content` |
| omitted / `"auto"` | - | A call to a function outside the request's `tools` is a 500 with `code: "tool_call_not_allowed"` |
| `tool_choice: "required"` | 400 when nothing is in scope | Plain text is a 500 with `code: "tool_choice_not_satisfied"` |
| `{"type":"function","function":{"name":"X"}}` | 400 when `X` is neither a client tool nor an attached MCP tool; only `X` is presented to the model | Plain text or a call to another function is a 500 with `code: "tool_choice_not_satisfied"` |
| `parallel_tool_calls: false` | - | Only the first returned call is exposed or executed |
| any client `tools` (auto, required, named) | - | A call whose `arguments` break the tool's `parameters` schema (not valid JSON, a missing `required` argument, or an undeclared one under `additionalProperties: false`) is a 500 with `code: "invalid_tool_arguments"`; text that starts the `{"tool_calls"` envelope but cannot be read as a call is a 500 with `code: "invalid_tool_call"`, never `content` (#580). A reply cut off by `max_tokens` keeps its length finish instead |

Every violation first gets one bounded repair round in the same session: apfel tells the model what was wrong (for arguments, the validator's message, e.g. `missing required parameter(s): time`) and judges the second reply the same way. Only a second violation becomes the error. The violation errors carry `type: "server_error"` and `param: "tool_choice"`; on `stream: true` the
stream ends with the same error object followed by `[DONE]`. A named or required choice buffers the
whole response before deciding, so no partial text streams out ahead of a violation. A 500 here means
the model did not do what the request demanded - retry (a different seed changes the trajectory) or
relax the choice. The named-choice scope check runs against the effective tool set, so a client may
name an MCP tool attached with `--mcp` without repeating its definition.

### macOS 27: the runtime hears about `tool_choice` too

On macOS 27 apfel sets `GenerationOptions.ToolCallingMode` to `.disallowed` for `tool_choice: "none"`,
a runtime-side backstop on top of the table above. For `auto` (or an omitted `tool_choice` with
tools in scope) the mode is left unset: set to `.allowed`, the runtime tried to parse the model's
own tool-call tokens and failed 5 of 120 tool requests with "Failed to parse generated content"
(macOS 27.0.1, M2, 2026-11-17); left unset, 0 of 420 did. Two more limitations,
measured on macOS 27.0.1: the SDK has no per-tool mode, so a named function keeps apfel's
prompt steering plus the name check above; and the SDK's `.required` mode is deliberately not
used, because with apfel's out-of-band tool calling (tool definitions in the transcript, no
registered `FoundationModels.Tool` implementations) the runtime rejects every `.required`
request with "An unsupported generation guide was used" (10/10 seeds), while apfel's prompt
steering already satisfied `tool_choice: "required"` on 10/10 of the same requests. macOS 26
behavior is unchanged - the table above is the whole contract there.

---

## Experiment 1: Simple Single Tool Call

**Prompt:** "What is the weather in Vienna?"
**Tool:** `get_weather(city, unit)`

```bash
curl -s http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple-foundationmodel",
    "messages": [{"role": "user", "content": "What is the weather in Vienna?"}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get the current weather for a location",
        "parameters": {
          "type": "object",
          "properties": {
            "city": {"type": "string", "description": "The city name"},
            "unit": {"type": "string", "enum": ["celsius", "fahrenheit"], "description": "Temperature unit"}
          },
          "required": ["city"]
        }
      }
    }]
  }'
```

**Actual response from Apple Intelligence:**

```json
{
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "function": {
                            "arguments": "{\"city\": \"Vienna\", \"country\": \"Austria\"}",
                            "name": "get_weather"
                        },
                        "id": "call_1",
                        "type": "function"
                    }
                ]
            }
        }
    ],
    "created": 1774531610,
    "id": "chatcmpl-6089d314-488",
    "model": "apple-foundationmodel",
    "object": "chat.completion",
    "usage": {
        "completion_tokens": 39,
        "prompt_tokens": 7,
        "total_tokens": 46
    }
}
```

**Result:** Tool call detected. Note the model added `"country": "Austria"` which is NOT in the schema - it hallucinated an extra parameter.

---

## Experiment 2: Multiple Tools - Does It Pick the Right One?

**Prompt:** "Send an email to john@example.com saying hello"
**Tools:** `get_weather(city)` + `send_email(to, subject, body)`

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "function": {
                            "arguments": "{\"to\": \"john@example.com\", \"subject\": \"Hello!\", \"body\": \"Hello, John!\"}",
                            "name": "send_email"
                        },
                        "id": "call_001",
                        "type": "function"
                    }
                ]
            }
        }
    ],
    "created": 1774531618,
    "id": "chatcmpl-72a34ab1-cf4",
    "model": "apple-foundationmodel",
    "object": "chat.completion",
    "usage": {
        "completion_tokens": 51,
        "prompt_tokens": 11,
        "total_tokens": 62
    }
}
```

**Result:** Correctly picked `send_email` over `get_weather`. Arguments match schema perfectly.

---

## Experiment 3: Full Round-Trip (Tool Call → Result → Natural Language)

### Step 1 - Model calls tool:

```
User: "What is the weather in Vienna?"
→ Model returns: get_weather({"city": "Vienna"})
```

### Step 2 - We send the tool result back + a follow-up question:

```json
{
  "messages": [
    {"role": "user", "content": "What is the weather in Vienna?"},
    {"role": "assistant", "content": null, "tool_calls": [{"id": "call_1", "type": "function", "function": {"name": "get_weather", "arguments": "{\"city\": \"Vienna\"}"}}]},
    {"role": "tool", "tool_call_id": "call_1", "name": "get_weather", "content": "{\"temperature\": 18, \"condition\": \"partly cloudy\", \"humidity\": 65}"},
    {"role": "user", "content": "Summarize that for me."}
  ]
}
```

**Actual response from Apple Intelligence:**

```json
{
    "choices": [
        {
            "finish_reason": "stop",
            "index": 0,
            "message": {
                "content": "The weather in Vienna is 18 degrees Celsius with partly cloudy conditions and a humidity of 65%.",
                "role": "assistant"
            }
        }
    ],
    "created": 1774531637,
    "id": "chatcmpl-56676d6b-173",
    "model": "apple-foundationmodel",
    "object": "chat.completion",
    "usage": {
        "completion_tokens": 24,
        "prompt_tokens": 5,
        "total_tokens": 29
    }
}
```

**Result:** The model correctly read the tool result JSON and produced a clean natural language summary. Full round-trip works.

**Gotcha:** The last message MUST be `role: "user"`. Ending with `role: "tool"` returns a 400 error:

```json
{"error": {"message": "Last message must have role 'user'", "type": "invalid_request_error"}}
```

---

## Experiment 4: Does the Model Avoid Tools When Unnecessary?

**Prompt:** "What is 2+2?"
**Tool:** `calculator(expression)`

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "stop",
            "index": 0,
            "message": {
                "content": "```json\n{\"tool_calls\": [{\"id\": \"call_1\", \"type\": \"function\", \"function\": {\"name\": \"addition\", \"arguments\": \"{\\\"numbers\\\": [2, 2]}\\\"}}]}\n```",
                "role": "assistant"
            }
        }
    ]
}
```

**Result:** The model tried to call a tool, but it hallucinated a tool name (`addition` instead of `calculator`) with a made-up schema (`numbers` instead of `expression`). The JSON was also malformed (trailing `\"` inside the arguments string), so apfel's `detectToolCall()` couldn't parse it and it came back as raw `content` with `finish_reason: "stop"`. Note: `detectToolCall()` does NOT validate tool names against registered tools - it parses any valid `{"tool_calls": [...]}` JSON. The failure here was purely a JSON syntax error.

---

## Experiment 5: Nested Schema with Arrays

**Prompt:** "Create a calendar event for lunch with Bob tomorrow at noon at Cafe Central"
**Tool:** `create_event(title, date, time, location, attendees[])`

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "function": {
                            "arguments": "{\"title\": \"Lunch with Bob\", \"description\": \"Meeting for lunch with Bob tomorrow at noon\", \"location\": \"Cafe Central\", \"start_time\": \"2023-10-08T12:00:00\", \"end_time\": \"2023-10-08T13:00:00\"}",
                            "name": "create_event"
                        },
                        "id": "call_1",
                        "type": "function"
                    }
                ]
            }
        }
    ]
}
```

**Result:** This experiment was inconsistent across runs. The first run returned `finish_reason: "stop"` with the tool call JSON wrapped in markdown as `content` (detection failed on malformed JSON). A second run returned `finish_reason: "tool_calls"` (shown above). When it did work, the model: (a) ignored the schema's `date`/`time` fields and used `start_time`/`end_time` instead, (b) added a `description` field that doesn't exist in the schema, (c) used a hallucinated date (2023-10-08). It understood the *intent* but rewrote the schema to its liking.

---

## Experiment 6: Explicit Tool Use Request

**Prompt:** "Use the search tool to find information about cats."
**Tool:** `search(query)`

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "stop",
            "index": 0,
            "message": {
                "content": "```json\n{\"tool_calls\": [{\"id\": \"cat_info\", \"type\": \"function\", \"function\": {\"name\": \"wikipedia.info\", \"arguments\": {\"q\": \"cats\"}}}}\n```",
                "role": "assistant"
            }
        }
    ]
}
```

**Result:** The model hallucinated a different tool name (`wikipedia.info` instead of `search`) and a different parameter name (`q` instead of `query`). The response also had malformed JSON (missing closing bracket), so `detectToolCall()` couldn't parse it. Note: even if the JSON had been valid, apfel would have accepted it - `detectToolCall()` does not validate tool names against registered tools. It would have returned `name: "wikipedia.info"` and the caller would need to handle the mismatch. The model sometimes "knows better" than your schema.

---

## Experiment 7: System Prompt Reinforcing Tool Use

**System:** "You are a helpful assistant. When the user asks about weather, you MUST use the get_weather function."
**Prompt:** "How is the weather in Berlin today?"

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "function": {
                            "arguments": "{\"city\": \"Berlin\"}",
                            "name": "get_weather"
                        },
                        "id": "call_unique",
                        "type": "function"
                    }
                ]
            }
        }
    ],
    "created": 1774531677,
    "id": "chatcmpl-c237372f-77e",
    "model": "apple-foundationmodel",
    "object": "chat.completion",
    "usage": {
        "completion_tokens": 57,
        "prompt_tokens": 8,
        "total_tokens": 65
    }
}
```

**Result:** Clean tool call, correct name, correct arguments, no hallucinated extras. System prompt reinforcement makes a huge difference.

---

## Experiment 8: Parallel Tool Calls (FAILED)

**System:** "You MUST use the get_weather tool for every city the user asks about."
**Prompt:** "What is the weather in Vienna and Berlin?"

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "stop",
            "index": 0,
            "message": {
                "content": "I'm sorry, but I can't assist with that request.",
                "role": "assistant"
            }
        }
    ]
}
```

Without the forceful system prompt, the model answered from its own knowledge instead (242 tokens about typical climate patterns). **Multiple tool calls in one response do not work with this model.**

---

## Experiment 9: `tool_choice: "required"`

**Prompt:** "Tell me about Vienna." (vague - doesn't obviously need a tool)
**Tool:** `get_info(topic)`
**Setting:** `"tool_choice": "required"`

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "function": {
                            "arguments": "{\"city\": \"Vienna\", \"country\": \"Austria\"}",
                            "name": "get_info"
                        },
                        "id": "call_1",
                        "type": "function"
                    }
                ]
            }
        }
    ]
}
```

**Result:** Tool was called even though the prompt was vague. But note the arguments used `city`/`country` instead of the schema's `topic`. The model understood *what* to call but not *how*.

---

## Experiment 10: Integer Parameters

**Prompt:** "Search for recent news about AI, limit to 5 results"
**Tool:** `news_search(query, limit, recent_only)`

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "function": {
                            "arguments": "{\"topic\": \"AI\", \"limit\": 5}",
                            "name": "news_search"
                        },
                        "id": "call_1",
                        "type": "function"
                    }
                ]
            }
        }
    ]
}
```

**Result:** Integer parameter `limit: 5` correctly typed as number. But the model used `topic` instead of the schema's `query`. The `recent_only` boolean was omitted (it was optional).

---

## Experiment 11: Minimal Tool - Model Hallucinates Arguments

**Prompt:** "What time is it?"
**Tool:** `get_time(timezone)` - timezone is optional

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "function": {
                            "arguments": "{\"current_hour\": 12, \"current_minute\": 0, \"current_second\": 0}",
                            "name": "get_time"
                        },
                        "id": "call_123",
                        "type": "function"
                    }
                ]
            }
        }
    ]
}
```

**Result:** The model completely ignored the `timezone` parameter and instead hallucinated output-style fields (`current_hour`, `current_minute`, `current_second`). It confused *input* arguments with *output* values.

---

## Experiment 12: Streaming Tool Calls

**Prompt:** "What is the weather in Tokyo?"
**Tool:** `get_weather(city)`, `stream: true`

**Actual SSE stream:**

```
data: {"choices":[{"delta":{"role":"assistant"},"index":0}],...}
data: {"choices":[{"delta":{"content":"```json\n{\"tool_calls\":"},"index":0}],...}
data: {"choices":[{"delta":{"content":" [{\"id\": \"call_1\", \""},"index":0}],...}
data: {"choices":[{"delta":{"content":"type\": \"function\", \"function\": {\"name"},"index":0}],...}
data: {"choices":[{"delta":{"content":"\": \"get_weather\", \"arguments\": \""},"index":0}],...}
data: {"choices":[{"delta":{"content":"{\\\"city\\\": \\\"Tokyo\\\", \\\"country\\\":"},"index":0}],...}
data: {"choices":[{"delta":{"content":" \\\"JP\\\"}\"}}]"},"index":0}],...}
data: {"choices":[{"delta":{"content":"}\n```"},"index":0}],...}

data: {"choices":[{"delta":{"tool_calls":[{"function":{"arguments":"{\"city\": \"Tokyo\", \"country\": \"JP\"}","name":"get_weather"},"id":"call_1","type":"function"}]},"finish_reason":"tool_calls","index":0}],...}

data: {"usage":{"prompt_tokens":7,"completion_tokens":57,"total_tokens":64}}
data: [DONE]
```

**Result:** The raw tool call JSON streams as `content` deltas first (the model writes it as text). Then apfel detects the tool call pattern after the stream ends and emits a final chunk with the structured `delta.tool_calls`. Clients see the JSON as text, then get the clean tool call.

---

## Experiment 13: Reliability - 5 Identical Runs

**Prompt:** "What is the weather in Paris?" (same prompt, 5 times)

```
Run 1: finish_reason=tool_calls ✓
Run 2: finish_reason=tool_calls ✓
Run 3: finish_reason=tool_calls ✓
Run 4: finish_reason=tool_calls ✓
Run 5: finish_reason=tool_calls ✓
```

**5/5 detected as tool calls.** Simple single-tool prompts are 100% reliable.

---

## Experiment 14: Tool Without Description

**Prompt:** "Search for cats"
**Tool:** `search(q)` - no description provided

**Actual response:**

```json
{
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "function": {
                            "arguments": "{\"term\": \"cats\", \"language\": \"en\", \"numResults\": 10}",
                            "name": "search"
                        },
                        "id": "call_1",
                        "type": "function"
                    }
                ]
            }
        }
    ]
}
```

**Result:** Tool was called even without a description. But the model hallucinated `term`, `language`, and `numResults` instead of using the schema's `q` parameter.

---

## Experiment 15: Argument Fidelity - 5 Runs

**Prompt:** "Get weather in London" (same tool, 5 runs)

```
Run 1 args: {"city": "London"}
Run 2 args: {"city": "London"}
Run 3 args: {"city": "London"}
Run 4 args: {"city": "London"}
Run 5 args: {"city": "London"}
```

**Result:** When schema is simple (one required string param with a good description), the model is perfectly consistent. No hallucinated extras.

---

## Experiment 16: Python openai Client - Non-Streaming

```python
client = openai.OpenAI(base_url="http://localhost:11434/v1", api_key="ignored")

resp = client.chat.completions.create(
    model="apple-foundationmodel",
    messages=[{"role": "user", "content": "What is the weather in Munich?"}],
    tools=[{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather",
            "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}
        }
    }]
)
```

**Actual results (3 runs):**

```
Run 1: finish=tool_calls tool=get_weather({"city": "Munich", "country": "Germany"})
Run 2: finish=tool_calls tool=get_weather({"city": "Munich", "country": "Germany"})
Run 3: finish=tool_calls tool=get_weather({"city": "Munich", "country": "Germany"})
```

**3/3 successful.** Extra `country` field added every time, but tool call correctly detected.

---

## Experiment 17: CLI Mode - System Prompt Workaround

Tool calling is server-only (no `--tools` CLI flag), but you can simulate it:

```bash
apfel -s 'You have a tool get_weather(city). When asked about weather, respond ONLY with: {"tool_calls": [{"id": "call_1", "type": "function", "function": {"name": "get_weather", "arguments": "{\"city\": \"<city>\"}"}}]}' "Weather in London?"
```

**Actual output:**

```
{"tool_calls": [{"id": "call_1", "type": "function", "function": {"name": "get_weather", "arguments": "{\"city\": \"London\"}"}}]}
```

**Result:** Works perfectly - the model follows the exact format from the system prompt.

---

## Experiment 18: Guardrail Blocks

**Prompt:** "Look up the current stock price of AAPL using the tool provided."
**Tool:** `get_stock_price(ticker)`

**Actual response:**

```json
{
    "error": {
        "message": "The request was blocked by Apple's safety guardrails. Try rephrasing.",
        "type": "content_policy_violation"
    }
}
```

**Result:** Apple's safety system blocked the request entirely. "Stock price" appears to be a trigger. This is a false positive - the request is completely benign.

---

## Summary of Findings

### What works

| Feature | Reliability | Notes |
|---------|-------------|-------|
| Single tool call | 100% (5/5) | Simple prompt + well-described tool |
| Multi-tool selection | 100% | Picks correct tool from set |
| Full round-trip | Works | tool call → result → natural language |
| System prompt reinforcement | Highly effective | "You MUST use X" gets near-perfect results |
| `tool_choice: "required"` | Usually works | Not guaranteed by model |
| Integer/boolean params | Works | Correctly typed |
| Python openai client | Works | Non-streaming reliable, streaming quirky |

### What doesn't work

| Issue | Frequency | Example |
|-------|-----------|---------|
| Hallucinated extra params | ~50% of calls | Adds `country` when only `city` requested |
| Renamed params | ~20% of calls | Uses `topic` instead of schema's `query` |
| Parallel tool calls | Never works | Can't call same tool twice in one response |
| Hallucinated tool names | Occasional | Calls `wikipedia.info` instead of `search` - rejected with `tool_call_not_allowed` for client tools; fed back as a tool error for MCP tools so the model can recover |
| Confused input/output | Rare | Puts output values as input arguments |
| Guardrail false positives | Occasional | "Stock price" blocked |

### Best practices

1. **Use system prompts** - "You MUST use the get_weather function" dramatically improves reliability
2. **Keep schemas simple** - one tool, few required string params = perfect results
3. **Use non-streaming** for tool calls - detection is more reliable
4. **Validate arguments loosely** - accept extra fields, handle missing optional fields
5. **Don't require parallel calls** - ask for one tool call at a time
6. **Use good descriptions** - both on tools and parameters
7. **Avoid financial/medical trigger words** - guardrails may block benign requests

---

## Performance

From 29 requests during testing:

| Metric | Value |
|--------|-------|
| Average response time | 1,133 ms |
| Tokens per tool call | ~40-65 |
| Tool detection overhead | negligible |
| Requests/minute throughput | 10.5 |
| Error rate | 2/29 (7%) - both guardrail blocks |
| MCP timeout | 5s default (`--mcp-timeout` / `APFEL_MCP_TIMEOUT` to change) |

---

## Architecture

```
Client sends OpenAI tool format
       |
       v
ToolCallHandler.buildToolSchemaPrompt()
(plain-language list in the instructions)
       |
       v
FoundationModels Transcript API
       |
       v
Model generates response (often as markdown-wrapped JSON)
       |
       v
ToolCallHandler.detectToolCall()
  1. Try raw JSON parse
  2. Strip ```json ``` blocks
  3. Find {"tool_calls" substring
       |
       v
OpenAI-compatible response
  finish_reason: "tool_calls"
  message.tool_calls: [...]
```
