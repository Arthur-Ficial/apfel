# Error Handling

`ApfelError` provides a stable, typed classification layer around runtime failures that matter to callers:

- user-facing labels via ``ApfelError/cliLabel``
- OpenAI-compatible error types and HTTP statuses
- retryability via ``ApfelError/isRetryable``

For MCP and request validation, use:

- ``MCPError``
- ``ChatRequestValidationFailure``
- ``UnsupportedChatParameter``

These types are designed to give downstream callers stable messages without forcing them to parse localized or framework-specific strings.
