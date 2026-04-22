# ``ApfelCore``

Pure Swift building blocks for exposing Apple's on-device Foundation Models in your own apps and tools.

`ApfelCore` contains the FoundationModels-free parts of apfel: OpenAI-compatible request and message types, context-trimming configuration, tool-calling helpers, MCP wire helpers, schema parsing, retry classification, and request validation.

## Overview

Use `ApfelCore` when you want to:

- build your own FoundationModels client while keeping request/response types OpenAI-compatible
- reuse apfel's context-strategy and validation logic in another Swift package or app
- parse MCP and tool-calling payloads without taking a dependency on the apfel executable target

## Topics

### Essentials

- <doc:GettingStarted>

### Core Areas

- <doc:ContextStrategies>
- <doc:OpenAITypes>
- <doc:ToolCalling>
- <doc:ErrorHandling>
