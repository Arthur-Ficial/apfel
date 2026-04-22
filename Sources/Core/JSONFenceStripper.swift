// ============================================================================
// JSONFenceStripper.swift — Remove Markdown code fences around JSON output
// Part of ApfelCore — pure Swift, no external dependencies
// ============================================================================

import Foundation

/// Strips a surrounding Markdown code fence from JSON content.
///
/// Supports both JSON-tagged and untagged fences. When
/// `response_format: { "type": "json_object" }` is
/// requested, the OpenAI spec requires the message content to be valid JSON.
/// Apple's on-device model often emits a fenced block despite explicit
/// instructions, so we post-process the output to deliver raw JSON.
///
/// - Returns the trimmed inner content when the input is fenced with an
///   opening three-backtick fence (optionally followed by `json`/`JSON`) on
///   its own line and a closing three-backtick fence on its own line.
/// - Returns the input trimmed of surrounding whitespace otherwise.
public enum JSONFenceStripper {
    public static func strip(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"), trimmed.hasSuffix("```") else {
            return content
        }

        // Find the end of the opening fence line.
        guard let firstNewline = trimmed.firstIndex(of: "\n") else {
            return content
        }
        let fenceTag = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 3)..<firstNewline]
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        // Only strip when the fence is JSON-flavored or untagged. Leave other
        // fenced blocks (```python ...```) intact so we do not corrupt them.
        guard fenceTag.isEmpty || fenceTag == "json" else {
            return content
        }

        // Strip the opening fence line and any trailing closing fence.
        let afterOpen = trimmed.index(after: firstNewline)
        var inner = String(trimmed[afterOpen...])
        if let closingRange = inner.range(of: "```", options: .backwards) {
            inner = String(inner[..<closingRange.lowerBound])
        }
        return inner.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
