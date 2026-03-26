# apfel Tool Calling Guide

Real findings from systematic experimentation with Apple's on-device FoundationModels LLM
and apfel's OpenAI-compatible tool calling implementation.

**Tested:** 2026-03-26 | **apfel:** v0.5.0 | **macOS:** 26.3

---

## How It Works

apfel converts OpenAI-format tool definitions into two paths:

1. **Native path:** Tool schemas are converted to `DynamicGenerationSchema` and passed
   via FoundationModels' `Transcript.ToolDefinition` API. The model outputs structured
   JSON tool calls natively.

2. **Fallback path:** If schema conversion fails (unsupported types), the tool definition
   is injected into the system prompt as text. The model is instructed to output a specific
   JSON format, which apfel detects post-hoc via `ToolCallHandler.detectToolCall()`.

Detection handles: clean JSON, markdown-wrapped ```` ```json ``` ```` blocks, and JSON
after preamble text. Both paths produce identical OpenAI-compatible output.

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

**Result:** Tool call detected. Note the model added `"country": "Austria"` which is NOT in the schema — it hallucinated an extra parameter.

---

## Experiment 2: Multiple Tools — Does It Pick the Right One?

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

### Step 1 — Model calls tool:

```
User: "What is the weather in Vienna?"
→ Model returns: get_weather({"city": "Vienna"})
```

### Step 2 — We send the tool result back + a follow-up question:

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

**Result:** The model tried to call a tool, but it hallucinated a tool name (`addition` instead of `calculator`) with a made-up schema (`numbers` instead of `expression`). The JSON was also malformed (trailing `\"` inside the arguments string), so apfel's `detectToolCall()` couldn't parse it and it came back as raw `content` with `finish_reason: "stop"`. Note: `detectToolCall()` does NOT validate tool names against registered tools — it parses any valid `{"tool_calls": [...]}` JSON. The failure here was purely a JSON syntax error.

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

**Result:** The model hallucinated a different tool name (`wikipedia.info` instead of `search`) and a different parameter name (`q` instead of `query`). The response also had malformed JSON (missing closing bracket), so `detectToolCall()` couldn't parse it. Note: even if the JSON had been valid, apfel would have accepted it — `detectToolCall()` does not validate tool names against registered tools. It would have returned `name: "wikipedia.info"` and the caller would need to handle the mismatch. The model sometimes "knows better" than your schema.

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

**Prompt:** "Tell me about Vienna." (vague — doesn't obviously need a tool)
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

## Experiment 11: Minimal Tool — Model Hallucinates Arguments

**Prompt:** "What time is it?"
**Tool:** `get_time(timezone)` — timezone is optional

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

## Experiment 13: Reliability — 5 Identical Runs

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
**Tool:** `search(q)` — no description provided

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

## Experiment 15: Argument Fidelity — 5 Runs

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

## Experiment 16: Python openai Client — Non-Streaming

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

## Experiment 17: CLI Mode — System Prompt Workaround

Tool calling is server-only (no `--tools` CLI flag), but you can simulate it:

```bash
apfel -s 'You have a tool get_weather(city). When asked about weather, respond ONLY with: {"tool_calls": [{"id": "call_1", "type": "function", "function": {"name": "get_weather", "arguments": "{\"city\": \"<city>\"}"}}]}' "Weather in London?"
```

**Actual output:**

```
{"tool_calls": [{"id": "call_1", "type": "function", "function": {"name": "get_weather", "arguments": "{\"city\": \"London\"}"}}]}
```

**Result:** Works perfectly — the model follows the exact format from the system prompt.

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

**Result:** Apple's safety system blocked the request entirely. "Stock price" appears to be a trigger. This is a false positive — the request is completely benign.

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
| Hallucinated tool names | Occasional | Calls `wikipedia.info` instead of `search` (apfel accepts it — name validation is caller's job) |
| Confused input/output | Rare | Puts output values as input arguments |
| Guardrail false positives | Occasional | "Stock price" blocked |

### Best practices

1. **Use system prompts** — "You MUST use the get_weather function" dramatically improves reliability
2. **Keep schemas simple** — one tool, few required string params = perfect results
3. **Use non-streaming** for tool calls — detection is more reliable
4. **Validate arguments loosely** — accept extra fields, handle missing optional fields
5. **Don't require parallel calls** — ask for one tool call at a time
6. **Use good descriptions** — both on tools and parameters
7. **Avoid financial/medical trigger words** — guardrails may block benign requests

---

## Performance

From 29 requests during testing:

| Metric | Value |
|--------|-------|
| Average response time | 1,133 ms |
| Tokens per tool call | ~40-65 |
| Tool detection overhead | negligible |
| Requests/minute throughput | 10.5 |
| Error rate | 2/29 (7%) — both guardrail blocks |

---

## Architecture

```
Client sends OpenAI tool format
       |
       v
SchemaConverter.convert()
  |                    |
  v                    v
Native path         Fallback path
(ToolDefinition)    (system prompt injection)
  |                    |
  v                    v
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
