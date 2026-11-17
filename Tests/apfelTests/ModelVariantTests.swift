// ============================================================================
// ModelVariantTests.swift - which Apple Foundation Model serves (#576).
// Mapping per Apple's "Detecting available Apple Foundation Models":
// macOS 27 reports SystemLanguageModel.variant (.core3, .coreAdvanced3, or
// an unrecognized one with its displayName); macOS 26.4+ has AFM 2.1 Core,
// macOS 26.0 to 26.3 AFM 2 Core.
// ============================================================================

import Foundation
import ApfelCore

func runModelVariantTests() {
    test("macOS 27 core3 maps to id core3, AFM 3 Core (#576)") {
        let variant = ModelVariant.macOS27(isCore3: true, isCoreAdvanced3: false, displayName: "AFM 3 Core")
        try assertEqual(variant.id, "core3")
        try assertEqual(variant.displayName, "AFM 3 Core")
    }

    test("macOS 27 coreAdvanced3 maps to id coreAdvanced3 (#576)") {
        let variant = ModelVariant.macOS27(isCore3: false, isCoreAdvanced3: true, displayName: "AFM 3 Core Advanced")
        try assertEqual(variant.id, "coreAdvanced3")
        try assertEqual(variant.displayName, "AFM 3 Core Advanced")
    }

    test("an unrecognized macOS 27+ variant keeps the runtime's display name as id and name") {
        let variant = ModelVariant.macOS27(isCore3: false, isCoreAdvanced3: false, displayName: "AFM 4 Core")
        try assertEqual(variant.id, "AFM 4 Core")
        try assertEqual(variant.displayName, "AFM 4 Core")
    }

    test("an empty runtime display name falls back to the known names") {
        try assertEqual(ModelVariant.macOS27(isCore3: true, isCoreAdvanced3: false, displayName: "").displayName, "AFM 3 Core")
        try assertEqual(ModelVariant.macOS27(isCore3: false, isCoreAdvanced3: true, displayName: " ").displayName, "AFM 3 Core Advanced")
        try assertEqual(ModelVariant.macOS27(isCore3: false, isCoreAdvanced3: false, displayName: "").id, "unknown")
    }

    test("macOS 26.4 and later is AFM 2.1 Core, 26.0 to 26.3 AFM 2 Core (#576)") {
        try assertEqual(ModelVariant.macOS26(atLeast26_4: true), ModelVariant(id: "core2_1", displayName: "AFM 2.1 Core"))
        try assertEqual(ModelVariant.macOS26(atLeast26_4: false), ModelVariant(id: "core2", displayName: "AFM 2 Core"))
    }

    test("the JSON object uses id and display_name") {
        let json = ModelVariant(id: "core3", displayName: "AFM 3 Core").jsonObject
        try assertEqual(json["id"], "core3")
        try assertEqual(json["display_name"], "AFM 3 Core")
        try assertEqual(json.count, 2)
    }
}
