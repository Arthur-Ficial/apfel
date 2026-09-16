// ============================================================================
// ContextWindow.swift — Context window size with measurement provenance
//
// Pure ApfelCore type so the measured-vs-assumed distinction is unit-testable
// without FoundationModels. TokenCounter adapts the SDK's raw contextSize
// into this type; CLI and server endpoints render the distinction for humans
// and wire clients respectively (#491).
// ============================================================================

import Foundation

/// The model's context window size and whether it was measured from the SDK
/// or assumed from a known floor.
///
/// `TokenCounter` applies a high-water mark and a 4096-token floor to
/// `SystemLanguageModel.contextSize` (#192). This type carries the result
/// alongside a boolean so reporting surfaces can distinguish "the SDK told
/// us 8192" from "the SDK returned 0 and we assumed 4096".
public struct ContextWindow: Sendable, Equatable {
    /// Context window size in tokens (always > 0).
    public let size: Int
    /// True when `size` was read from the SDK; false when it is the 4096 floor.
    public let measured: Bool

    public init(size: Int, measured: Bool) {
        self.size = size
        self.measured = measured
    }
}
