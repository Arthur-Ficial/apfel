// ============================================================================
// ToolResultTruncator.swift — Truncate oversized MCP tool results
// Part of ApfelCore — pure data types, no FoundationModels dependency
// ============================================================================

public enum ToolResultTruncator: Sendable {

    /// Truncate a tool result string to fit within a character budget.
    ///
    /// When the text exceeds `maxCharacters`, returns the first 2/3 of the
    /// budget as a head, a human-readable marker noting the truncation, and
    /// the last 1/3 of the budget as a tail. This preserves both the
    /// beginning (usually the most relevant data) and the end (often
    /// contains closing structure) of the result.
    ///
    /// When the text fits, it is returned unchanged.
    public static func truncate(_ text: String, maxCharacters: Int) -> String {
        guard text.count > maxCharacters else { return text }
        let marker = "\n\n[tool output truncated: showing \(maxCharacters) of \(text.count) characters]\n\n"
        let available = max(0, maxCharacters - marker.count)
        let headSize = available * 2 / 3
        let tailSize = available - headSize
        let head = String(text.prefix(headSize))
        let tail = tailSize > 0 ? String(text.suffix(tailSize)) : ""
        return head + marker + tail
    }
}
