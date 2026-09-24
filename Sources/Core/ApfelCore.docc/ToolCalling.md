# Tool Calling

Use `ToolCallHandler` when you need to:

- describe fallback tool schemas in prompt text
- normalize model-emitted argument strings into valid JSON
- parse OpenAI-style `tool_calls` payloads out of a model response

`SchemaParser` and `SchemaIR` complement this by parsing raw JSON Schema text into a deterministic intermediate representation you can adapt to another runtime. The parser resolves local `$ref` / `$defs` pointers by expanding them in place, carries numeric and array bounds in the `boundedInteger`, `boundedNumber` and `boundedArray` cases, gives object and enum nodes names that are unique per distinct shape, and rejects validation keywords it cannot represent with a path-specific `SchemaParser.Error` (`unsupportedConstraint`, `invalidConstraint`, `externalReference`, `unresolvedReference`, `cyclicReference`). Switch over `SchemaIR` and `SchemaParser.Error` with a `default` branch: both enums gain cases in minor releases.
