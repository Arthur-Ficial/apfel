# TICKET-014: Allow role:"tool" as last message

**Status:** Open
**Priority:** P2 (breaks standard OpenAI tool calling flow)
**Found by:** apfelpilot integration testing

---

## Problem

apfel rejects requests where the last message has `role: "tool"`:

```json
{"error": {"message": "Last message must have role 'user'", "type": "invalid_request_error"}}
```

The standard OpenAI tool calling flow is:

```
1. user: "What's the weather?"
2. assistant: tool_calls: [get_weather({city: "Vienna"})]
3. tool: {temp: 18, condition: "cloudy"}     <-- this is the last message
4. → model responds with natural language
```

OpenAI's API accepts `role: "tool"` as the last message and responds using the tool result. apfel requires adding a synthetic `role: "user"` message after every tool result ("Continue with the task."), which wastes tokens and confuses the model.

## Impact

- Any standard OpenAI SDK tool-calling flow breaks without workaround
- apfelpilot must append a synthetic user message after every tool result
- The synthetic message uses ~20 tokens per iteration (wasted from the 4096 budget)
- The extra user message sometimes confuses the model ("Continue" makes it call more tools when it should stop)

## Suggested Fix

In `Handlers.swift`, change the validation at line ~53:

```swift
// Before:
guard chatRequest.messages.last?.role == "user" else { ... }

// After: allow "tool" as last message too
guard ["user", "tool"].contains(chatRequest.messages.last?.role) else { ... }
```

And in `ContextManager.swift`, handle `role: "tool"` as the final prompt:
- Extract the tool result content
- Use it as the user's input to the model (the model should respond to it)

## Files to modify

- `Sources/Handlers.swift` - validation around line 53
- `Sources/ContextManager.swift` - session building to handle tool-last sequences
