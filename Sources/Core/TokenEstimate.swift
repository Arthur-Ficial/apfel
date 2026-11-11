// ============================================================================
// TokenEstimate.swift - the fallback token estimate when the on-device
// tokenizer is unavailable (macOS 26.0-26.3, or the model not ready).
// Part of ApfelCore.
//
// Text is estimated at four characters per token. A transcript also carries
// chat-template framing the text estimate cannot see. Measured on macOS
// 27.0.1 with runtime-reported prompt tokens: about 4.5 tokens per message
// and about 66 per transcript. Without it, trimming a long history on macOS
// 26.1 kept roughly 1000 tokens too many and the runtime rejected the request
// (#544).
// ============================================================================

public enum TokenEstimate {
    /// Framing tokens per transcript entry (role markers, separators).
    public static let perEntryFramingTokens = 5
    /// Framing tokens per transcript (template header and footer).
    public static let fixedFramingTokens = 64

    /// The fallback estimate for a whole transcript: the text estimate plus
    /// framing. An empty transcript has no framing.
    public static func transcriptFallback(textTokens: Int, entries: Int) -> Int {
        guard entries > 0 else { return textTokens }
        return textTokens + fixedFramingTokens + entries * perEntryFramingTokens
    }
}
