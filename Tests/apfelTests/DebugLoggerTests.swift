import Foundation
import ApfelCore

func runDebugLoggerTests() {
    test("ApfelDebugConfiguration defaults to false") {
        try assertEqual(ApfelDebugConfiguration.isEnabled, false)
    }
    test("ApfelDebugConfiguration can be toggled") {
        let original = ApfelDebugConfiguration.isEnabled
        defer { ApfelDebugConfiguration.isEnabled = original }
        ApfelDebugConfiguration.isEnabled = true
        try assertEqual(ApfelDebugConfiguration.isEnabled, true)
    }
}
