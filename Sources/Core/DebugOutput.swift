import os

/// Process-wide debug logging configuration shared by the CLI and server.
///
/// The value is intentionally synchronous to keep hot logging call-sites cheap,
/// but the storage is lock-protected so reads and writes remain data-race-safe
/// under Swift 6 strict concurrency.
package enum ApfelDebugConfiguration {
    private static let storage = OSAllocatedUnfairLock<Bool>(initialState: false)

    /// Enables or disables debug logging.
    package static var isEnabled: Bool {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}
