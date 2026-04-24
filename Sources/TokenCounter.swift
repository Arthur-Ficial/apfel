// ============================================================================
// TokenCounter.swift — Token counting via FoundationModels API
//
// Uses SystemLanguageModel.tokenCount(for:) (macOS 26.4+) with chars/4 fallback.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore

actor TokenCounter {
    static let shared = TokenCounter()
    private let model = SystemLanguageModel.default

    /// Count tokens in text using the real FoundationModels API.
    /// Falls back to chars/4 approximation on error.
    func count(_ text: String) async -> Int {
        guard !text.isEmpty else { return 0 }
        if #available(macOS 26.4, *) {
            do {
                return try await model.tokenCount(for: text)
            } catch {
                return max(1, text.count / 4)
            }
        } else {
            return max(1, text.count / 4)
        }
    }

    /// Real context window size from the model.
    var contextSize: Int {
        model.contextSize
    }

    /// Tokens available for model input given a reserved output budget.
    func inputBudget(reservedForOutput: Int = 512) -> Int {
        contextSize - reservedForOutput
    }

    /// Whether the model is available for generation.
    var isAvailable: Bool {
        model.isAvailable
    }

    /// Current availability as our pure ApfelCore enum. Adapts Apple's
    /// `SystemLanguageModel.Availability` into our `ModelAvailability`
    /// so the rest of apfel can reason about the specific unavailable
    /// reason without depending on FoundationModels.
    var availability: ModelAvailability {
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return .appleIntelligenceNotEnabled
            case .deviceNotEligible:
                return .deviceNotEligible
            case .modelNotReady:
                return .modelNotReady
            @unknown default:
                return .unknownUnavailable
            }
        @unknown default:
            return .unknownUnavailable
        }
    }

    /// Supported languages as locale identifier strings.
    /// Callers should fetch this ONCE at startup (see Server.swift) - it touches
    /// the FoundationModels SDK, and a crash observed in apfel-gui#4 suggests
    /// repeated mid-flight access on Hummingbird's dispatch queue can destabilize
    /// the process in some macOS 26.4 environments.
    var supportedLanguages: [String] {
        var ids: [String] = []
        for language in model.supportedLanguages {
            if let id = language.languageCode?.identifier {
                ids.append(id)
            }
        }
        return ids
    }

    /// Count tokens for transcript entries using the real API.
    /// More accurate than counting individual text strings.
    func count(entries: [Transcript.Entry]) async -> Int {
        guard !entries.isEmpty else { return 0 }
        if #available(macOS 26.4, *) {
            do {
                return try await model.tokenCount(for: entries)
            } catch {
                return fallbackCount(entries: entries)
            }
        } else {
            return fallbackCount(entries: entries)
        }
    }

    private func fallbackCount(entries: [Transcript.Entry]) -> Int {
        var total = 0
        for entry in entries {
            switch entry {
            case .instructions(let i):
                for seg in i.segments { if case .text(let t) = seg { total += max(1, t.content.count / 4) } }
            case .prompt(let p):
                for seg in p.segments { if case .text(let t) = seg { total += max(1, t.content.count / 4) } }
            case .response(let r):
                for seg in r.segments { if case .text(let t) = seg { total += max(1, t.content.count / 4) } }
            case .toolOutput(let o):
                for seg in o.segments { if case .text(let t) = seg { total += max(1, t.content.count / 4) } }
            case .toolCalls(let tc):
                total += tc.count * 20
            @unknown default:
                break
            }
        }
        return total
    }
}
