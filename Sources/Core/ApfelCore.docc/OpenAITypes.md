# OpenAI Types

`ApfelCore` models the OpenAI-compatible chat-completions payloads apfel accepts and emits.

Key types include:

- ``ChatCompletionRequest``
- ``OpenAIMessage``
- ``MessageContent``
- ``OpenAITool``
- ``ToolChoice``
- ``ResponseFormat``
- ``StopSequences`` and ``StopSequenceMatcher`` - OpenAI `stop` decoding, limits, and the incremental output-side matcher shared by streaming and non-streaming generation

These types are pure Swift values, `Sendable`, and hashable where it is useful for callers building caches, sets, or maps of request metadata.
