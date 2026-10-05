// ============================================================================
// ExitCodes.swift - CLI exit-code constants and ApfelError -> exit-code mapping.
// Part of ApfelCLI so the mapping is unit-testable; main.swift delegates here.
//
// Exit codes are a stable CLI contract documented in the man page. Changes
// here must stay in sync with `apfel.1` and with the bidirectional-coverage
// integration test (`Tests/integration/test_man_page.py`).
// ============================================================================

import Foundation
import ApfelCore

/// Stable CLI exit codes and the `ApfelError` -> exit-code mapping.
/// Documented in the man page; regression-locked by `ExitCodeMapTests`.
public enum ApfelExitCodes {
    public static let success: Int32 = 0
    public static let runtimeError: Int32 = 1
    public static let usageError: Int32 = 2
    public static let guardrail: Int32 = 3
    public static let contextOverflow: Int32 = 4
    public static let modelUnavailable: Int32 = 5
    public static let rateLimited: Int32 = 6
    /// `--code` (#373): the model answered normally but the response contains
    /// no fenced code block. Distinct from `runtimeError` so scripts can
    /// branch on "re-prompt or fall back" vs "the run itself failed".
    public static let noCode: Int32 = 7

    /// Build the CLI error line for a classified error.
    /// When file input was attached and the error is a guardrail violation,
    /// appends a hint about `--permissive` so the user has an actionable
    /// remedy instead of a wall (#505).
    public static func cliErrorMessage(for error: ApfelError, hasFileInput: Bool) -> String {
        var msg = "\(error.cliLabel) \(error.openAIMessage)"
        if error == .guardrailViolation && hasFileInput {
            msg += " Attached file text was refused; retry with --permissive."
        }
        return msg
    }

    /// Map a classified `ApfelError` to its documented CLI exit code.
    public static func code(for error: ApfelError) -> Int32 {
        switch error {
        case .guardrailViolation:  return guardrail
        case .refusal:             return guardrail
        case .contextOverflow:     return contextOverflow
        case .rateLimited:         return rateLimited
        case .concurrentRequest:   return rateLimited
        case .assetsUnavailable:   return runtimeError
        case .unsupportedGuide:    return runtimeError
        case .decodingFailure:     return runtimeError
        case .unsupportedLanguage: return runtimeError
        case .toolExecution:       return runtimeError
        case .unknown:             return runtimeError
        }
    }
}
