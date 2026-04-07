// ============================================================================
// Service.swift — macOS background service management via launchd
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import Foundation
import Darwin
import ApfelCore

struct ServiceStatusReport: Sendable {
    enum State: String, Sendable {
        case notInstalled = "not installed"
        case stopped = "stopped"
        case running = "running"
    }

    let state: State
    let launchdLoaded: Bool
    let reachable: Bool
    let config: ServerServiceConfig?
    let paths: ServicePaths
}

struct CommandResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String

    var output: String {
        [stdout, stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

private enum ServiceError: Error {
    case notInstalled
    case unreadableConfig(String)
    case invalidConfig(String)
    case launchctlFailed(String)
    case filesystem(String)

    var message: String {
        switch self {
        case .notInstalled:
            return "service not installed. Run: apfel service install"
        case .unreadableConfig(let path):
            return "cannot read service config: \(path)"
        case .invalidConfig(let details):
            return "invalid service config: \(details)"
        case .launchctlFailed(let details):
            return details
        case .filesystem(let details):
            return details
        }
    }
}

struct ServiceManager {
    private let paths: ServicePaths
    private let label: String
    private let domain: String
    private let currentExecutablePath: String
    private let currentWorkingDirectory: URL
    private let commandRunner: @Sendable (String, [String]) -> CommandResult
    private let fileManager: FileManager

    init(
        homeDirectory: URL = currentServiceHomeDirectory(),
        label: String = apfelServiceLabel,
        currentExecutablePath: String = ProcessInfo.processInfo.arguments[0],
        currentWorkingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        commandRunner: @escaping @Sendable (String, [String]) -> CommandResult = runCommand,
        fileManager: FileManager = .default
    ) {
        self.paths = makeServicePaths(homeDirectory: homeDirectory)
        self.label = label
        self.domain = "gui/\(getuid())"
        self.currentExecutablePath = currentExecutablePath
        self.currentWorkingDirectory = currentWorkingDirectory
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    func install(config: ServerServiceConfig, tokenAuto: Bool) throws -> ServiceInstallPreparation {
        try ensureDirectories()

        let prepared = prepareServiceInstallConfig(
            config,
            workingDirectory: currentWorkingDirectory,
            tokenAuto: tokenAuto
        )
        try writeConfig(prepared.config)
        try writeLaunchAgent()
        try bootoutIfLoaded()
        try bootstrap()
        try kickstart()
        return prepared
    }

    func start() throws {
        guard fileManager.fileExists(atPath: paths.plistFile.path) else {
            throw ServiceError.notInstalled
        }

        if isLoaded() {
            try kickstart()
        } else {
            try bootstrap()
            try kickstart()
        }
    }

    func stop() throws {
        guard fileManager.fileExists(atPath: paths.plistFile.path) else {
            throw ServiceError.notInstalled
        }
        try bootoutIfLoaded()
    }

    func restart() throws {
        guard fileManager.fileExists(atPath: paths.plistFile.path) else {
            throw ServiceError.notInstalled
        }
        try bootoutIfLoaded()
        try bootstrap()
        try kickstart()
    }

    func uninstall() throws {
        try bootoutIfLoaded()
        if fileManager.fileExists(atPath: paths.plistFile.path) {
            do {
                try fileManager.removeItem(at: paths.plistFile)
            } catch {
                throw ServiceError.filesystem("failed to remove LaunchAgent plist: \(paths.plistFile.path)")
            }
        }
    }

    func loadConfig() throws -> ServerServiceConfig {
        guard fileManager.fileExists(atPath: paths.configFile.path) else {
            throw ServiceError.unreadableConfig(paths.configFile.path)
        }
        do {
            let data = try Data(contentsOf: paths.configFile)
            return try JSONDecoder().decode(ServerServiceConfig.self, from: data)
        } catch let error as DecodingError {
            throw ServiceError.invalidConfig(String(describing: error))
        } catch {
            throw ServiceError.unreadableConfig(paths.configFile.path)
        }
    }

    func status() async -> ServiceStatusReport {
        let config = try? loadConfig()
        let installed = fileManager.fileExists(atPath: paths.plistFile.path)
        let loaded = installed && isLoaded()
        let reachable = await isReachable(config: config)
        let state: ServiceStatusReport.State
        if !installed {
            state = .notInstalled
        } else if loaded || reachable {
            state = .running
        } else {
            state = .stopped
        }
        return ServiceStatusReport(
            state: state,
            launchdLoaded: loaded,
            reachable: reachable,
            config: config,
            paths: paths
        )
    }

    private func ensureDirectories() throws {
        do {
            try fileManager.createDirectory(at: paths.applicationSupportDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: paths.launchAgentsDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: paths.logsDirectory, withIntermediateDirectories: true)
        } catch {
            throw ServiceError.filesystem("failed to create service directories under \(paths.homeDirectory.path)")
        }
    }

    private func writeConfig(_ config: ServerServiceConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(config)
            try data.write(to: paths.configFile, options: .atomic)
        } catch {
            throw ServiceError.filesystem("failed to write service config: \(paths.configFile.path)")
        }
    }

    private func writeLaunchAgent() throws {
        let executablePath = stableExecutablePath(currentExecutablePath: currentExecutablePath)
        do {
            let plist = try makeServiceLaunchAgentPlist(
                executablePath: executablePath,
                servicePaths: paths,
                label: label
            )
            try Data(plist.utf8).write(to: paths.plistFile, options: .atomic)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.filesystem("failed to write LaunchAgent plist: \(paths.plistFile.path)")
        }
    }

    private func launchctl(_ args: [String], failureMessage: String) throws {
        let result = commandRunner("/bin/launchctl", args)
        guard result.status == 0 else {
            let suffix = result.output.isEmpty ? "" : "\n\(result.output)"
            throw ServiceError.launchctlFailed("\(failureMessage)\(suffix)")
        }
    }

    private func isLoaded() -> Bool {
        commandRunner("/bin/launchctl", ["print", "\(domain)/\(label)"]).status == 0
    }

    private func bootstrap() throws {
        try launchctl(
            ["bootstrap", domain, paths.plistFile.path],
            failureMessage: "launchctl bootstrap failed for \(label)"
        )
    }

    private func kickstart() throws {
        try launchctl(
            ["kickstart", "-k", "\(domain)/\(label)"],
            failureMessage: "launchctl kickstart failed for \(label)"
        )
    }

    private func bootoutIfLoaded() throws {
        guard isLoaded() else { return }
        try launchctl(
            ["bootout", domain, paths.plistFile.path],
            failureMessage: "launchctl bootout failed for \(label)"
        )
    }

    private func isReachable(config: ServerServiceConfig?) async -> Bool {
        guard let config else { return false }
        guard let url = URL(string: "\(serviceEndpoint(host: config.host, port: config.port))/health") else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }
}

func performServiceCommand(
    subcommand: ServiceSubcommand,
    config: ServerServiceConfig,
    tokenAuto: Bool
) async throws {
    let manager = ServiceManager()
    let servicePaths = makeServicePaths(homeDirectory: currentServiceHomeDirectory())

    switch subcommand {
    case .install:
        let prepared = try manager.install(config: config, tokenAuto: tokenAuto)
        print("""
        \(styled("apfel service", .cyan, .bold))
        \(styled("├", .dim)) status:   installed
        \(styled("├", .dim)) endpoint: \(serviceEndpoint(host: prepared.config.host, port: prepared.config.port))
        \(styled("├", .dim)) config:   \(servicePaths.configFile.path)
        \(styled("├", .dim)) logs:     \(servicePaths.logsDirectory.path)
        \(styled("├", .dim)) launchd:  \(servicePaths.plistFile.path)
        """)
        if let token = prepared.generatedToken {
            print("\(styled("├", .dim)) \(styled("token:", .yellow)) \(token)")
        }
        print("\(styled("└", .dim)) ready")

    case .start:
        try manager.start()
        print("service started")

    case .stop:
        try manager.stop()
        print("service stopped")

    case .restart:
        try manager.restart()
        print("service restarted")

    case .status:
        let report = await manager.status()
        print("\(styled("apfel service", .cyan, .bold))")
        print("\(styled("├", .dim)) status:   \(report.state.rawValue)")
        if let config = report.config {
            print("\(styled("├", .dim)) endpoint: \(serviceEndpoint(host: config.host, port: config.port))")
        }
        print("\(styled("├", .dim)) launchd:  \(report.launchdLoaded ? "loaded" : "not loaded")")
        print("\(styled("├", .dim)) config:   \(report.paths.configFile.path)")
        print("\(styled("├", .dim)) logs:     \(report.paths.logsDirectory.path)")
        print("\(styled("└", .dim)) plist:    \(report.paths.plistFile.path)")

    case .uninstall:
        try manager.uninstall()
        print("service uninstalled")

    case .run:
        throw ServiceError.invalidConfig("service run must be handled before performServiceCommand()")
    }
}

func makeRuntimeServerConfig(
    from config: ServerServiceConfig,
    tokenWasAutoGenerated: Bool = false
) -> ServerConfig {
    ServerConfig(
        host: config.host,
        port: config.port,
        cors: config.cors,
        maxConcurrent: config.maxConcurrent,
        debug: config.debug,
        allowedOrigins: config.originCheckEnabled ? config.allowedOrigins : ["*"],
        originCheckEnabled: config.originCheckEnabled,
        token: config.token,
        tokenWasAutoGenerated: tokenWasAutoGenerated,
        publicHealth: config.publicHealth,
        retryEnabled: config.retryEnabled,
        retryCount: config.retryCount
    )
}

private func runCommand(_ executable: String, _ args: [String]) -> CommandResult {
    let process = Process()
    let stdout = Pipe()
    let stderr = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return CommandResult(status: 1, stdout: "", stderr: error.localizedDescription)
    }

    return CommandResult(
        status: process.terminationStatus,
        stdout: String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
        stderr: String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    )
}

private func currentServiceHomeDirectory() -> URL {
    if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty {
        return URL(fileURLWithPath: home, isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
}
