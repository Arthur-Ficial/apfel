import Foundation
import ApfelCore

func runServiceSupportTests() {
    test("ServiceSubcommand parses install") {
        try assertEqual(ServiceSubcommand(rawValue: "install"), .install)
    }

    test("ServerServiceConfig round-trips through JSON") {
        let config = ServerServiceConfig(
            host: "0.0.0.0",
            port: 11435,
            cors: true,
            maxConcurrent: 2,
            debug: true,
            allowedOrigins: ["http://localhost:3000"],
            originCheckEnabled: false,
            token: "secret-token",
            publicHealth: true,
            mcpServerPaths: ["/tmp/calc.py"]
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerServiceConfig.self, from: data)
        try assertEqual(decoded, config)
    }

    test("defaultServerServiceConfig uses hardcoded defaults") {
        let config = defaultServerServiceConfig(environment: [:])
        try assertEqual(config.host, "127.0.0.1")
        try assertEqual(config.port, 11434)
        try assertNil(config.token)
        try assertEqual(config.allowedOrigins, OriginValidator.defaultAllowedOrigins)
    }

    test("defaultServerServiceConfig reads env host port and token") {
        let config = defaultServerServiceConfig(environment: [
            "APFEL_HOST": "0.0.0.0",
            "APFEL_PORT": "11435",
            "APFEL_TOKEN": "env-token",
        ])
        try assertEqual(config.host, "0.0.0.0")
        try assertEqual(config.port, 11435)
        try assertEqual(config.token, "env-token")
    }

    test("prepareServiceInstallConfig auto-generates token once") {
        let config = ServerServiceConfig(token: nil)
        let prepared = prepareServiceInstallConfig(
            config,
            workingDirectory: URL(fileURLWithPath: "/tmp/apfel"),
            tokenAuto: true,
            tokenGenerator: { "generated-token" }
        )

        try assertEqual(prepared.generatedToken, "generated-token")
        try assertEqual(prepared.config.token, "generated-token")
    }

    test("prepareServiceInstallConfig preserves explicit token when token-auto is disabled") {
        let config = ServerServiceConfig(token: "manual-token")
        let prepared = prepareServiceInstallConfig(
            config,
            workingDirectory: URL(fileURLWithPath: "/tmp/apfel"),
            tokenAuto: false,
            tokenGenerator: { "generated-token" }
        )

        try assertNil(prepared.generatedToken)
        try assertEqual(prepared.config.token, "manual-token")
    }

    test("prepareServiceInstallConfig absolutizes relative MCP paths") {
        let config = ServerServiceConfig(mcpServerPaths: ["mcp/calculator/server.py", "/opt/tools/weather.py"])
        let prepared = prepareServiceInstallConfig(
            config,
            workingDirectory: URL(fileURLWithPath: "/Users/david/Development/apfel"),
            tokenAuto: false
        )

        try assertEqual(
            prepared.config.mcpServerPaths,
            [
                "/Users/david/Development/apfel/mcp/calculator/server.py",
                "/opt/tools/weather.py",
            ]
        )
    }

    test("stableExecutablePath prefers Homebrew opt path for Cellar installs") {
        let resolved = stableExecutablePath(
            currentExecutablePath: "/opt/homebrew/Cellar/apfel/0.9.0/bin/apfel",
            fileExists: { path in path == "/opt/homebrew/opt/apfel/bin/apfel" }
        )

        try assertEqual(resolved, "/opt/homebrew/opt/apfel/bin/apfel")
    }

    test("stableExecutablePath falls back to resolved binary when opt path missing") {
        let resolved = stableExecutablePath(
            currentExecutablePath: "/usr/local/bin/apfel",
            fileExists: { _ in false }
        )

        try assertEqual(resolved, "/usr/local/bin/apfel")
    }

    test("makeServiceLaunchAgentPlist includes keepalive run-at-load and service run args") {
        let plist = try makeServiceLaunchAgentPlist(
            executablePath: "/opt/homebrew/opt/apfel/bin/apfel",
            servicePaths: makeServicePaths(homeDirectory: URL(fileURLWithPath: "/Users/tester"))
        )

        let data = Data(plist.utf8)
        let decoded = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        guard let dict = decoded else {
            throw TestFailure("expected plist dictionary")
        }

        try assertEqual(dict["Label"] as? String, apfelServiceLabel)
        try assertEqual(dict["RunAtLoad"] as? Bool, true)
        try assertEqual(dict["KeepAlive"] as? Bool, true)
        try assertEqual(
            dict["ProgramArguments"] as? [String],
            ["/opt/homebrew/opt/apfel/bin/apfel", "service", "run"]
        )
        try assertEqual(dict["StandardOutPath"] as? String, "/Users/tester/Library/Logs/apfel/service.stdout.log")
        try assertEqual(dict["StandardErrorPath"] as? String, "/Users/tester/Library/Logs/apfel/service.stderr.log")
    }
}
