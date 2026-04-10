// ============================================================================
// OutputFormat.swift - Output format enum for the apfel CLI
// Part of ApfelCLI - CLI-specific types, separate from ApfelCore domain logic
// ============================================================================

import Foundation

/// Supported output formats for responses.
/// - `plain`: Human-readable text (default). Supports ANSI colors when on a TTY.
/// - `json`: Machine-readable JSON. Single object for prompts, JSONL for chat.
public enum OutputFormat: String, Sendable {
    case plain
    case json
}
