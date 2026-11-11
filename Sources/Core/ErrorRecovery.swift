// ============================================================================
// ErrorRecovery.swift — what happens to the conversation when a turn fails.
//
// Pure policy, mirroring macOS 27's TranscriptErrorHandlingPolicy
// (.preserveTranscript / .revertTranscript) so the same choice exists on
// macOS 26, where the engine applies it by hand.
// ============================================================================

/// Conversation state policy for a failed generation turn.
public enum ErrorRecovery: String, Sendable, Equatable, CaseIterable {
    /// Keep whatever the runtime left in the conversation (the failed prompt
    /// and any partial response).
    case preserve
    /// Restore the conversation to its pre-turn state, as if the failed turn
    /// never happened.
    case revert
}
