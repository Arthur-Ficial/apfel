// ServerSecurityTests - pure server-hardening predicate tests
// Covers host classification (#228), exposed-without-token warning gate (#228),
// Host-header allowlisting (#230), and MCP env scrubbing (#229).

import ApfelCore

func runServerSecurityTests() {

    // MARK: - isLoopbackHost (#228)

    test("isLoopbackHost: 127.0.0.1 is loopback") {
        try assertTrue(ServerSecurity.isLoopbackHost("127.0.0.1"))
    }

    test("isLoopbackHost: localhost is loopback (case-insensitive)") {
        try assertTrue(ServerSecurity.isLoopbackHost("localhost"))
        try assertTrue(ServerSecurity.isLoopbackHost("LocalHost"))
    }

    test("isLoopbackHost: ::1 and [::1] are loopback") {
        try assertTrue(ServerSecurity.isLoopbackHost("::1"))
        try assertTrue(ServerSecurity.isLoopbackHost("[::1]"))
    }

    test("isLoopbackHost: 0.0.0.0 is NOT loopback") {
        try assertTrue(!ServerSecurity.isLoopbackHost("0.0.0.0"))
    }

    test("isLoopbackHost: LAN address is NOT loopback") {
        try assertTrue(!ServerSecurity.isLoopbackHost("192.168.1.10"))
    }

    // MARK: - shouldWarnExposedWithoutToken (#228)

    test("exposed warning: 0.0.0.0 without token warns") {
        try assertTrue(ServerSecurity.shouldWarnExposedWithoutToken(host: "0.0.0.0", hasToken: false))
    }

    test("exposed warning: 0.0.0.0 WITH token does not warn") {
        try assertTrue(!ServerSecurity.shouldWarnExposedWithoutToken(host: "0.0.0.0", hasToken: true))
    }

    test("exposed warning: loopback without token does not warn") {
        try assertTrue(!ServerSecurity.shouldWarnExposedWithoutToken(host: "127.0.0.1", hasToken: false))
        try assertTrue(!ServerSecurity.shouldWarnExposedWithoutToken(host: "localhost", hasToken: false))
    }

    test("exposed warning: LAN bind without token warns") {
        try assertTrue(ServerSecurity.shouldWarnExposedWithoutToken(host: "192.168.1.10", hasToken: false))
    }

    // MARK: - scrubbedMCPEnvironment (#229)

    let dirtyEnv: [String: String] = [
        "PATH": "/usr/local/bin:/usr/bin:/bin",
        "HOME": "/Users/tester",
        "TMPDIR": "/var/folders/xy/tmp/",
        "LANG": "en_US.UTF-8",
        "LC_ALL": "en_US.UTF-8",
        "PYTHONPATH": "/opt/pp",
        "PYTHONHOME": "/opt/py",
        "VIRTUAL_ENV": "/opt/venv",
        "APFEL_TOKEN": "server-secret",
        "APFEL_MCP_TOKEN": "mcp-secret",
        "APFEL_HOST": "0.0.0.0",
        "AWS_SECRET_ACCESS_KEY": "leak",
        "OPENAI_API_KEY": "leak",
        "MY_ACCESS_TOKEN": "leak",
        "GITHUB_TOKEN": "leak",
        "RANDOM_UNRELATED_VAR": "value",
    ]

    test("scrub: APFEL_ vars are excluded") {
        let scrubbed = ServerSecurity.scrubbedMCPEnvironment(from: dirtyEnv)
        try assertNil(scrubbed["APFEL_TOKEN"])
        try assertNil(scrubbed["APFEL_MCP_TOKEN"])
        try assertNil(scrubbed["APFEL_HOST"])
    }

    test("scrub: TOKEN/KEY/SECRET vars are excluded") {
        let scrubbed = ServerSecurity.scrubbedMCPEnvironment(from: dirtyEnv)
        try assertNil(scrubbed["AWS_SECRET_ACCESS_KEY"])
        try assertNil(scrubbed["OPENAI_API_KEY"])
        try assertNil(scrubbed["MY_ACCESS_TOKEN"])
        try assertNil(scrubbed["GITHUB_TOKEN"])
    }

    test("scrub: unrelated vars not on the allowlist are excluded") {
        let scrubbed = ServerSecurity.scrubbedMCPEnvironment(from: dirtyEnv)
        try assertNil(scrubbed["RANDOM_UNRELATED_VAR"])
    }

    test("scrub: PATH/HOME/TMPDIR/LANG pass through") {
        let scrubbed = ServerSecurity.scrubbedMCPEnvironment(from: dirtyEnv)
        try assertEqual(scrubbed["PATH"], "/usr/local/bin:/usr/bin:/bin")
        try assertEqual(scrubbed["HOME"], "/Users/tester")
        try assertEqual(scrubbed["TMPDIR"], "/var/folders/xy/tmp/")
        try assertEqual(scrubbed["LANG"], "en_US.UTF-8")
    }

    test("scrub: LC_* and PYTHON*/VIRTUAL_ENV pass through") {
        let scrubbed = ServerSecurity.scrubbedMCPEnvironment(from: dirtyEnv)
        try assertEqual(scrubbed["LC_ALL"], "en_US.UTF-8")
        try assertEqual(scrubbed["PYTHONPATH"], "/opt/pp")
        try assertEqual(scrubbed["PYTHONHOME"], "/opt/py")
        try assertEqual(scrubbed["VIRTUAL_ENV"], "/opt/venv")
    }

    test("scrub: PATH is synthesized when the parent has none") {
        let scrubbed = ServerSecurity.scrubbedMCPEnvironment(from: ["HOME": "/Users/tester"])
        try assertNotNil(scrubbed["PATH"])
        try assertTrue(scrubbed["PATH"]!.contains("/usr/bin"))
    }

    // MARK: - originValidationConstrains (#465)

    test("originValidationConstrains: normal list constrains") {
        try assertTrue(ServerSecurity.originValidationConstrains(
            originCheckEnabled: true,
            allowedOrigins: ["http://localhost", "http://127.0.0.1"]
        ))
    }

    test("originValidationConstrains: wildcard does not constrain") {
        try assertTrue(!ServerSecurity.originValidationConstrains(
            originCheckEnabled: true,
            allowedOrigins: ["http://localhost", "*"]
        ))
    }

    test("originValidationConstrains: wildcard alone does not constrain") {
        try assertTrue(!ServerSecurity.originValidationConstrains(
            originCheckEnabled: true,
            allowedOrigins: ["*"]
        ))
    }

    test("originValidationConstrains: origin check disabled does not constrain") {
        try assertTrue(!ServerSecurity.originValidationConstrains(
            originCheckEnabled: false,
            allowedOrigins: ["http://localhost"]
        ))
    }

    test("originValidationConstrains: both disabled and wildcard does not constrain") {
        try assertTrue(!ServerSecurity.originValidationConstrains(
            originCheckEnabled: false,
            allowedOrigins: ["*"]
        ))
    }

    // MARK: - isAllowedHostHeader (#230 DNS-rebinding defense)

    test("host header: nil/empty Host is allowed (nothing to rebind)") {
        try assertTrue(ServerSecurity.isAllowedHostHeader(nil, bindHost: "127.0.0.1"))
        try assertTrue(ServerSecurity.isAllowedHostHeader("", bindHost: "127.0.0.1"))
    }

    test("host header: localhost allowed with and without port") {
        try assertTrue(ServerSecurity.isAllowedHostHeader("localhost", bindHost: "127.0.0.1"))
        try assertTrue(ServerSecurity.isAllowedHostHeader("localhost:11434", bindHost: "127.0.0.1"))
    }

    test("host header: 127.0.0.1 allowed with and without port") {
        try assertTrue(ServerSecurity.isAllowedHostHeader("127.0.0.1", bindHost: "127.0.0.1"))
        try assertTrue(ServerSecurity.isAllowedHostHeader("127.0.0.1:8080", bindHost: "127.0.0.1"))
    }

    test("host header: [::1] IPv6 loopback allowed with and without port") {
        try assertTrue(ServerSecurity.isAllowedHostHeader("[::1]", bindHost: "127.0.0.1"))
        try assertTrue(ServerSecurity.isAllowedHostHeader("[::1]:11434", bindHost: "127.0.0.1"))
    }

    test("host header: case-insensitive") {
        try assertTrue(ServerSecurity.isAllowedHostHeader("LocalHost:3000", bindHost: "127.0.0.1"))
    }

    test("host header: foreign host rejected (rebinding attacker domain)") {
        try assertTrue(!ServerSecurity.isAllowedHostHeader("attacker.com", bindHost: "127.0.0.1"))
        try assertTrue(!ServerSecurity.isAllowedHostHeader("attacker.com:11434", bindHost: "127.0.0.1"))
    }

    test("host header: subdomain of localhost rejected") {
        try assertTrue(!ServerSecurity.isAllowedHostHeader("localhost.evil.com", bindHost: "127.0.0.1"))
    }

    test("host header: the configured bind host is allowed") {
        try assertTrue(ServerSecurity.isAllowedHostHeader("myhost.local:11434", bindHost: "myhost.local"))
    }
}
