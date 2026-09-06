// ============================================================================
// ServerSecurity.swift - Pure server-hardening predicates (host classification,
// startup-warning gates, Host-header allowlisting, MCP env scrubbing).
// Lives in ApfelCore so it is unit-testable without Hummingbird or Foundation
// networking.
// ============================================================================

/// Pure decision logic for server security hardening. No I/O, no framework
/// dependencies - just predicates the CLI/server/MCP layers consult.
public enum ServerSecurity {

    /// True if `host` is a loopback bind address (traffic never leaves the box).
    public static func isLoopbackHost(_ host: String) -> Bool {
        switch host.lowercased() {
        case "127.0.0.1", "localhost", "::1", "[::1]":
            return true
        default:
            return false
        }
    }

    /// True when the server is bound to a non-loopback address with no bearer
    /// token: every host that can reach the socket can hit the inference
    /// endpoints with zero authentication (#228). Callers surface a loud warning.
    public static func shouldWarnExposedWithoutToken(host: String, hasToken: Bool) -> Bool {
        return !isLoopbackHost(host) && !hasToken
    }

    /// Minimal environment handed to a local (stdio) MCP subprocess (#229).
    ///
    /// A `Process` with `environment == nil` inherits apfel's entire environment,
    /// leaking `APFEL_TOKEN`/`APFEL_MCP_TOKEN` and any cloud/API keys in the shell
    /// to the third-party tool script. This returns an explicit allowlist instead:
    /// PATH/HOME/TMPDIR/LANG plus `LC_*`, `PYTHON*`, and `VIRTUAL_ENV` (what the
    /// calculator server and typical FastMCP/venv servers need). Everything else
    /// is dropped, and any `APFEL_*` var or any var whose name contains
    /// TOKEN/KEY/SECRET is excluded even if it would otherwise match. PATH is
    /// synthesized when absent so `/usr/bin/env python3` still resolves.
    public static func scrubbedMCPEnvironment(from parent: [String: String]) -> [String: String] {
        let exactAllow: Set<String> = ["PATH", "HOME", "TMPDIR", "LANG", "VIRTUAL_ENV"]
        let prefixAllow = ["LC_", "PYTHON"]
        var result: [String: String] = [:]
        for (key, value) in parent {
            let upper = key.uppercased()
            // Exclusions win over the allowlist.
            if upper.hasPrefix("APFEL_") { continue }
            if upper.contains("TOKEN") || upper.contains("KEY") || upper.contains("SECRET") { continue }
            if exactAllow.contains(upper) || prefixAllow.contains(where: { upper.hasPrefix($0) }) {
                result[key] = value
            }
        }
        if result["PATH"] == nil {
            result["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        }
        return result
    }

    /// True only when origin validation actually constrains requests (#465).
    ///
    /// `--no-origin-check` turns it off outright, but `--allowed-origins '*'`
    /// reaches the same posture by a different route: `OriginValidator.isAllowed`
    /// short-circuits to `true` for every origin. The startup banner and the
    /// #232 warning must key off this, not off `originCheckEnabled` alone.
    public static func originValidationConstrains(
        originCheckEnabled: Bool,
        allowedOrigins: [String]
    ) -> Bool {
        originCheckEnabled && !allowedOrigins.contains("*")
    }

    /// DNS-rebinding defense: is this request's `Host` header acceptable? (#230)
    ///
    /// Same-origin GET requests carry no Origin header, so origin checking alone
    /// cannot stop a rebinding page (`attacker.com` re-resolved to `127.0.0.1`)
    /// from reading `/health` and `/v1/models`. The canonical defense is a Host
    /// allowlist: accept only loopback names (`localhost`, `127.0.0.1`, `[::1]`,
    /// with or without a port) and the configured bind host. A missing/empty
    /// Host is allowed - there is nothing to rebind. Callers apply this only when
    /// bound to a loopback host; a deliberately network-exposed bind (`0.0.0.0`)
    /// receives Host headers we cannot enumerate and is the operator's choice.
    public static func isAllowedHostHeader(_ hostHeader: String?, bindHost: String) -> Bool {
        guard let hostHeader, !hostHeader.isEmpty else { return true }
        let name = hostWithoutPort(hostHeader).lowercased()
        let allowed: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]", bindHost.lowercased()]
        return allowed.contains(name)
    }

    // MARK: - Private

    /// Strip an optional `:port` suffix, keeping bracketed IPv6 literals intact.
    private static func hostWithoutPort(_ s: String) -> String {
        if s.hasPrefix("[") {
            // "[::1]" or "[::1]:8080" -> "[::1]"
            if let close = s.firstIndex(of: "]") {
                return String(s[...close])
            }
            return s
        }
        // "host:port" -> "host", but only when the suffix is a numeric port
        // (a bare unbracketed IPv6 like "::1" has no numeric-only tail).
        if let colon = s.lastIndex(of: ":") {
            let portPart = s[s.index(after: colon)...]
            if !portPart.isEmpty && portPart.allSatisfy(\.isNumber) {
                return String(s[..<colon])
            }
        }
        return s
    }
}
