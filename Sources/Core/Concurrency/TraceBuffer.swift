// ============================================================================
// TraceBuffer.swift — Append-only event log for streaming request traces
// ============================================================================

import Foundation

package actor TraceBuffer {
    private var events: [String]

    public init(events: [String]) {
        self.events = events
    }

    public func append(_ event: String) {
        events.append(event)
    }

    public func snapshot() -> [String] {
        events
    }
}
