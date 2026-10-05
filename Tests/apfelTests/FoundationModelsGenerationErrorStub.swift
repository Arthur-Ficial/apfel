import Foundation

/// Simulates a FoundationModels GenerationError without importing FoundationModels
/// into the pure ApfelCore test runner.
struct FoundationModelsGenerationErrorStub: Error, LocalizedError, CustomStringConvertible {
    let caseName: String
    let localizedMsg: String

    var errorDescription: String? { localizedMsg }

    var description: String {
        "GenerationError.\(caseName)(Context(debugDescription: \"\(localizedMsg)\"))"
    }
}

/// Shape of `LanguageModelSession.GenerationError` as macOS 27 hands it to a
/// binary linked against an SDK <= 26.x: the type name still says
/// GenerationError, but `String(reflecting:)` is only the message, no case
/// name (#193). The type name must contain "GenerationError" for the stub to
/// hit the same classifier branch as the real error.
struct CaselessGenerationErrorStub: Error, LocalizedError, CustomStringConvertible {
    let mirrorText: String
    let localizedMsg: String
    var errorDescription: String? { localizedMsg }
    var description: String { mirrorText }
}
