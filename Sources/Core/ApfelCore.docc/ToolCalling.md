# Tool Calling

Use `ToolCallHandler` when you need to:

- describe fallback tool schemas in prompt text
- normalize model-emitted argument strings into valid JSON
- parse OpenAI-style `tool_calls` payloads out of a model response

`SchemaParser` and `SchemaIR` complement this by parsing raw JSON Schema text into a deterministic intermediate representation you can adapt to another runtime.
