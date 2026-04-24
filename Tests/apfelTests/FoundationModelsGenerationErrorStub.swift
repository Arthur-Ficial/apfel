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
