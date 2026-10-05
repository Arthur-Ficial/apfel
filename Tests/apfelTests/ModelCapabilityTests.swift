// ============================================================================
// ModelCapabilityTests.swift — capability wire names + report (#510)
// Pure mapping in ApfelCore; the macOS-27 read lives in the main target.
// ============================================================================

import Foundation
import ApfelCore

func runModelCapabilityTests() {

    test("capability wire names are snake_case") {
        try assertEqual(ModelCapability.vision.rawValue, "vision")
        try assertEqual(ModelCapability.toolCalling.rawValue, "tool_calling")
        try assertEqual(ModelCapability.guidedGeneration.rawValue, "guided_generation")
        try assertEqual(ModelCapability.reasoning.rawValue, "reasoning")
    }

    test("allCases covers the four known capabilities") {
        try assertEqual(ModelCapability.allCases.count, 4)
    }

    test("a reported CapabilitiesReport carries names in order") {
        let report = CapabilitiesReport(capabilities: [.vision, .toolCalling, .guidedGeneration])
        try assertTrue(report.reported)
        try assertEqual(report.names, ["vision", "tool_calling", "guided_generation"])
    }

    test("notReported carries no names and reported=false") {
        let report = CapabilitiesReport.notReported
        try assertEqual(report.names, [])
        try assertTrue(!report.reported)
    }

    test("displayText for --model-info") {
        try assertEqual(
            CapabilitiesReport(capabilities: [.vision, .toolCalling]).displayText,
            "vision, tool_calling")
        try assertEqual(
            CapabilitiesReport(capabilities: []).displayText,
            "none reported")
        try assertTrue(
            CapabilitiesReport.notReported.displayText.contains("macOS 27"),
            CapabilitiesReport.notReported.displayText)
    }
}
