// ============================================================================
// ModelAvailabilityTests.swift - Tests for the pure ModelAvailability enum
// that mirrors SystemLanguageModel.Availability from FoundationModels.
// ============================================================================

import Foundation
import ApfelCore

func runModelAvailabilityTests() {

    // -- isAvailable --

    test("isAvailable is true only for .available") {
        try assertTrue(ModelAvailability.available.isAvailable)
        try assertTrue(!ModelAvailability.appleIntelligenceNotEnabled.isAvailable)
        try assertTrue(!ModelAvailability.deviceNotEligible.isAvailable)
        try assertTrue(!ModelAvailability.modelNotReady.isAvailable)
        try assertTrue(!ModelAvailability.unknownUnavailable.isAvailable)
    }

    // -- shortLabel --

    test("shortLabel for .available is 'yes'") {
        try assertEqual(ModelAvailability.available.shortLabel, "yes")
    }

    test("shortLabel for .appleIntelligenceNotEnabled mentions the cause") {
        let label = ModelAvailability.appleIntelligenceNotEnabled.shortLabel
        try assertTrue(label.hasPrefix("no"))
        try assertTrue(label.contains("Apple Intelligence"))
        try assertTrue(label.contains("not enabled"))
    }

    test("shortLabel for .deviceNotEligible mentions the cause") {
        let label = ModelAvailability.deviceNotEligible.shortLabel
        try assertTrue(label.hasPrefix("no"))
        try assertTrue(label.contains("device"))
        try assertTrue(label.contains("not eligible"))
    }

    test("shortLabel for .modelNotReady mentions the cause") {
        let label = ModelAvailability.modelNotReady.shortLabel
        try assertTrue(label.hasPrefix("no"))
        try assertTrue(label.contains("not ready"))
    }

    test("shortLabel for .unknownUnavailable mentions unknown") {
        let label = ModelAvailability.unknownUnavailable.shortLabel
        try assertTrue(label.hasPrefix("no"))
        try assertTrue(label.contains("unknown"))
    }

    // -- remediation --

    test("remediation for .available is a ready message") {
        try assertEqual(ModelAvailability.available.remediation, "Model is ready for requests.")
    }

    test("remediation for .appleIntelligenceNotEnabled points at System Settings") {
        let r = ModelAvailability.appleIntelligenceNotEnabled.remediation
        try assertTrue(r.contains("System Settings"))
        try assertTrue(r.contains("Apple Intelligence"))
    }

    test("remediation for .appleIntelligenceNotEnabled mentions Siri language match") {
        let r = ModelAvailability.appleIntelligenceNotEnabled.remediation
        try assertTrue(r.contains("Siri"))
        try assertTrue(r.contains("language"))
    }

    test("remediation for .appleIntelligenceNotEnabled links to Apple support article") {
        let r = ModelAvailability.appleIntelligenceNotEnabled.remediation
        try assertTrue(r.contains("https://support.apple.com/en-us/121115"))
    }

    test("remediation for .deviceNotEligible mentions Apple Silicon requirement") {
        let r = ModelAvailability.deviceNotEligible.remediation
        try assertTrue(r.contains("Apple Silicon"))
    }

    test("remediation for .deviceNotEligible explains it is not an apfel limitation") {
        let r = ModelAvailability.deviceNotEligible.remediation
        try assertTrue(r.contains("not an apfel limitation"))
    }

    test("remediation for .deviceNotEligible mentions regional restrictions") {
        let r = ModelAvailability.deviceNotEligible.remediation
        try assertTrue(r.contains("region"))
    }

    test("remediation for .deviceNotEligible suggests checking macOS updates") {
        let r = ModelAvailability.deviceNotEligible.remediation
        try assertTrue(r.contains("System Settings"))
    }

    test("remediation for .modelNotReady mentions download") {
        let r = ModelAvailability.modelNotReady.remediation
        try assertTrue(r.contains("download"))
    }

    test("remediation for .modelNotReady tells user to keep Mac on Wi-Fi and power") {
        let r = ModelAvailability.modelNotReady.remediation
        try assertTrue(r.contains("Wi-Fi"))
        try assertTrue(r.contains("power"))
    }

    test("remediation for .unknownUnavailable tells user to file an issue") {
        let r = ModelAvailability.unknownUnavailable.remediation
        try assertTrue(r.contains("github.com/Arthur-Ficial/apfel/issues"))
    }

    // -- Equatable --

    test("ModelAvailability is Equatable") {
        try assertEqual(ModelAvailability.available, ModelAvailability.available)
        try assertEqual(ModelAvailability.modelNotReady, ModelAvailability.modelNotReady)
        try assertTrue(ModelAvailability.available != ModelAvailability.modelNotReady)
    }
}
