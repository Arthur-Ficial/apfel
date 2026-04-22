# OpenAI Types

`ApfelCore` models the OpenAI-compatible chat-completions payloads apfel accepts and emits.

Key types include:

- ``ChatCompletionRequest``
- ``OpenAIMessage``
- ``MessageContent``
- ``OpenAITool``
- ``ToolChoice``
- ``ResponseFormat``

These types are pure Swift values, `Sendable`, and hashable where it is useful for callers building caches, sets, or maps of request metadata.
