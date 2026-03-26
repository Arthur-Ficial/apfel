# TICKET-013: Tool call arguments sometimes not valid JSON

**Status:** Open
**Priority:** P1 (breaks tool calling for consumers)
**Found by:** apfelpilot integration testing

---

## Problem

When the on-device model returns tool calls, the `arguments` field is sometimes a **plain string** instead of a JSON object string. Examples observed:

```json
{"function": {"name": "list_dir", "arguments": "desktop"}}
{"function": {"name": "run_cmd", "arguments": "ls -l"}}
```

The OpenAI spec requires `arguments` to be a **JSON-encoded string**:
```json
{"function": {"name": "list_dir", "arguments": "{\"path\": \"desktop\"}"}}
```

## Impact

- Any OpenAI SDK client calling `json.loads(arguments)` will crash
- apfelpilot had to add `_infer_args()` to guess which parameter the plain string maps to
- The Python `openai` client may silently fail or produce empty args

## Suggested Fix

In `Handlers.swift` or `ToolCallHandler.swift`, after extracting tool call arguments, check if the value is valid JSON. If not, wrap it:

```swift
// If arguments is a plain string (not JSON), wrap it as the first required param
if let args = fn["arguments"] as? String,
   !args.hasPrefix("{") && !args.hasPrefix("[") {
    // Look up first required param from tool definition
    let param = toolDef.parameters.first?.name ?? "value"
    fn["arguments"] = "{\"\(param)\": \"\(args)\"}"
}
```

## Also observed

- Model sometimes returns `arguments` as a JSON **object** (not string): `"arguments": {"city": "Vienna"}` - this is handled by `parseToolCallJSON` already but is also non-spec
- Model returns empty `arguments` (`{}` or `""`) while putting the actual tool call in the response content as markdown-wrapped JSON - this is a native FoundationModels behavior, not an apfel bug

## Files to modify

- `Sources/Core/ToolCallHandler.swift` - `parseToolCallJSON()` around line 164
- `Sources/Handlers.swift` - tool call extraction in both streaming and non-streaming paths
