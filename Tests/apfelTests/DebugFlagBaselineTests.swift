// ============================================================================
// DebugFlagBaselineTests.swift — Package-internal contract for the future-safe debug
// configuration introduced by issue #105.
//
// The old `nonisolated(unsafe) var apfelDebugEnabled` was data-race-prone and
// not library-grade. The replacement must still be easy to use from sync and
// async contexts, but it should remain package-scoped instead of leaking into
// the public `ApfelCore` semver surface.
// ============================================================================

import Foundation
import ApfelCore

func runDebugFlagBaselineTests() {
    test("ApfelDebugConfiguration.isEnabled is typed as Bool") {
        let snapshot: Bool = ApfelDebugConfiguration.isEnabled
        try assertTrue(snapshot == true || snapshot == false)
    }

    test("ApfelDebugConfiguration.isEnabled has default value false at test-runner startup") {
        try assertEqual(ApfelDebugConfiguration.isEnabled, false)
    }

    test("ApfelDebugConfiguration supports synchronous write + read") {
        let original = ApfelDebugConfiguration.isEnabled
        defer { ApfelDebugConfiguration.isEnabled = original }
        ApfelDebugConfiguration.isEnabled = true
        try assertEqual(ApfelDebugConfiguration.isEnabled, true)
        ApfelDebugConfiguration.isEnabled = false
        try assertEqual(ApfelDebugConfiguration.isEnabled, false)
    }

    test("nested save/restore idiom restores prior value") {
        let original = ApfelDebugConfiguration.isEnabled
        defer { ApfelDebugConfiguration.isEnabled = original }

        ApfelDebugConfiguration.isEnabled = true
        do {
            let inner = ApfelDebugConfiguration.isEnabled
            defer { ApfelDebugConfiguration.isEnabled = inner }
            ApfelDebugConfiguration.isEnabled = false
            try assertEqual(ApfelDebugConfiguration.isEnabled, false)
        }
        try assertEqual(ApfelDebugConfiguration.isEnabled, true)
    }

    testAsync("ApfelDebugConfiguration reads synchronously from an async context") {
        let _: Bool = ApfelDebugConfiguration.isEnabled
    }

    testAsync("ApfelDebugConfiguration writes synchronously from an async context") {
        let original = ApfelDebugConfiguration.isEnabled
        defer { ApfelDebugConfiguration.isEnabled = original }
        ApfelDebugConfiguration.isEnabled = true
        try assertEqual(ApfelDebugConfiguration.isEnabled, true)
    }
}
