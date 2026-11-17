// ============================================================================
// ModelVariant.swift - which Apple Foundation Model is serving (#576).
// Part of ApfelCore - pure Swift, no FoundationModels, no availability checks.
//
// Apple's "Detecting available Apple Foundation Models" lists the variants a
// device may run: AFM 3 Core or AFM 3 Core Advanced on OS 27 (one per device,
// Core Advanced on M3 or newer Macs), AFM 2.1 Core from 26.4, AFM 2 Core from
// 26.0. macOS 27 reports the variant at runtime
// (SystemLanguageModel.variant); before 27 the OS version decides. The engine
// reads the runtime and calls the matching factory here.
// ============================================================================

import Foundation

/// The on-device model variant: a stable `id` for code and a
/// `displayName` for people.
public struct ModelVariant: Sendable, Equatable, Hashable {
    /// Stable identifier: `core3`, `coreAdvanced3`, `core2_1`, `core2`, or
    /// the runtime's display name for a variant this apfel does not know.
    public let id: String
    /// Human-readable name, e.g. "AFM 3 Core Advanced".
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    /// The variant a macOS 27+ runtime reports.
    /// - Parameters:
    ///   - isCore3: the runtime variant equals `.core3`.
    ///   - isCoreAdvanced3: the runtime variant equals `.coreAdvanced3`.
    ///   - displayName: the runtime's `displayName`.
    public static func macOS27(isCore3: Bool, isCoreAdvanced3: Bool, displayName: String) -> ModelVariant {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCoreAdvanced3 {
            return ModelVariant(id: "coreAdvanced3", displayName: name.isEmpty ? "AFM 3 Core Advanced" : name)
        }
        if isCore3 {
            return ModelVariant(id: "core3", displayName: name.isEmpty ? "AFM 3 Core" : name)
        }
        return ModelVariant(id: name.isEmpty ? "unknown" : name, displayName: name.isEmpty ? "unknown" : name)
    }

    /// The variant on macOS 26, which does not report one: AFM 2.1 Core from
    /// 26.4, AFM 2 Core before.
    public static func macOS26(atLeast26_4: Bool) -> ModelVariant {
        atLeast26_4
            ? ModelVariant(id: "core2_1", displayName: "AFM 2.1 Core")
            : ModelVariant(id: "core2", displayName: "AFM 2 Core")
    }

    /// `{"id": ..., "display_name": ...}` for `/v1/models` and `/health`.
    public var jsonObject: [String: String] {
        ["id": id, "display_name": displayName]
    }
}
