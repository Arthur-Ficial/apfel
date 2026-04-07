import Foundation

public let apfelServiceLabel = "com.arthurficial.apfel"

public enum ServiceSubcommand: String, CaseIterable, Sendable {
    case install
    case start
    case stop
    case restart
    case status
    case uninstall
    case run
}

public struct ServerServiceConfig: Codable, Equatable, Sendable {
    public var host: String
    public var port: Int
    public var cors: Bool
    public var maxConcurrent: Int
    public var debug: Bool
    public var allowedOrigins: [String]
    public var originCheckEnabled: Bool
    public var token: String?
    public var publicHealth: Bool
    public var mcpServerPaths: [String]
    public var retryEnabled: Bool
    public var retryCount: Int

    public init(
        host: String = "127.0.0.1",
        port: Int = 11434,
        cors: Bool = false,
        maxConcurrent: Int = 5,
        debug: Bool = false,
        allowedOrigins: [String] = OriginValidator.defaultAllowedOrigins,
        originCheckEnabled: Bool = true,
        token: String? = nil,
        publicHealth: Bool = false,
        mcpServerPaths: [String] = [],
        retryEnabled: Bool = false,
        retryCount: Int = 3
    ) {
        self.host = host
        self.port = port
        self.cors = cors
        self.maxConcurrent = maxConcurrent
        self.debug = debug
        self.allowedOrigins = allowedOrigins
        self.originCheckEnabled = originCheckEnabled
        self.token = token
        self.publicHealth = publicHealth
        self.mcpServerPaths = mcpServerPaths
        self.retryEnabled = retryEnabled
        self.retryCount = retryCount
    }

    enum CodingKeys: String, CodingKey {
        case host
        case port
        case cors
        case maxConcurrent
        case debug
        case allowedOrigins
        case originCheckEnabled
        case token
        case publicHealth
        case mcpServerPaths
        case retryEnabled
        case retryCount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.host = try container.decodeIfPresent(String.self, forKey: .host) ?? "127.0.0.1"
        self.port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 11434
        self.cors = try container.decodeIfPresent(Bool.self, forKey: .cors) ?? false
        self.maxConcurrent = try container.decodeIfPresent(Int.self, forKey: .maxConcurrent) ?? 5
        self.debug = try container.decodeIfPresent(Bool.self, forKey: .debug) ?? false
        self.allowedOrigins = try container.decodeIfPresent([String].self, forKey: .allowedOrigins) ?? OriginValidator.defaultAllowedOrigins
        self.originCheckEnabled = try container.decodeIfPresent(Bool.self, forKey: .originCheckEnabled) ?? true
        self.token = try container.decodeIfPresent(String.self, forKey: .token)
        self.publicHealth = try container.decodeIfPresent(Bool.self, forKey: .publicHealth) ?? false
        self.mcpServerPaths = try container.decodeIfPresent([String].self, forKey: .mcpServerPaths) ?? []
        self.retryEnabled = try container.decodeIfPresent(Bool.self, forKey: .retryEnabled) ?? false
        self.retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 3
    }
}

public func defaultServerServiceConfig(environment: [String: String]) -> ServerServiceConfig {
    ServerServiceConfig(
        host: environment["APFEL_HOST"] ?? "127.0.0.1",
        port: Int(environment["APFEL_PORT"] ?? "") ?? 11434,
        token: environment["APFEL_TOKEN"]
    )
}

public struct ServiceInstallPreparation: Equatable, Sendable {
    public let config: ServerServiceConfig
    public let generatedToken: String?

    public init(config: ServerServiceConfig, generatedToken: String?) {
        self.config = config
        self.generatedToken = generatedToken
    }
}

public struct ServicePaths: Equatable, Sendable {
    public let homeDirectory: URL
    public let applicationSupportDirectory: URL
    public let configFile: URL
    public let launchAgentsDirectory: URL
    public let plistFile: URL
    public let logsDirectory: URL
    public let stdoutLog: URL
    public let stderrLog: URL

    public init(
        homeDirectory: URL,
        applicationSupportDirectory: URL,
        configFile: URL,
        launchAgentsDirectory: URL,
        plistFile: URL,
        logsDirectory: URL,
        stdoutLog: URL,
        stderrLog: URL
    ) {
        self.homeDirectory = homeDirectory
        self.applicationSupportDirectory = applicationSupportDirectory
        self.configFile = configFile
        self.launchAgentsDirectory = launchAgentsDirectory
        self.plistFile = plistFile
        self.logsDirectory = logsDirectory
        self.stdoutLog = stdoutLog
        self.stderrLog = stderrLog
    }
}

public func makeServicePaths(homeDirectory: URL) -> ServicePaths {
    let library = homeDirectory.appendingPathComponent("Library", isDirectory: true)
    let appSupport = library.appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent("apfel", isDirectory: true)
    let launchAgents = library.appendingPathComponent("LaunchAgents", isDirectory: true)
    let logs = library.appendingPathComponent("Logs", isDirectory: true)
        .appendingPathComponent("apfel", isDirectory: true)
    return ServicePaths(
        homeDirectory: homeDirectory,
        applicationSupportDirectory: appSupport,
        configFile: appSupport.appendingPathComponent("server.json"),
        launchAgentsDirectory: launchAgents,
        plistFile: launchAgents.appendingPathComponent("\(apfelServiceLabel).plist"),
        logsDirectory: logs,
        stdoutLog: logs.appendingPathComponent("service.stdout.log"),
        stderrLog: logs.appendingPathComponent("service.stderr.log")
    )
}

public func prepareServiceInstallConfig(
    _ config: ServerServiceConfig,
    workingDirectory: URL,
    tokenAuto: Bool,
    tokenGenerator: () -> String = { UUID().uuidString }
) -> ServiceInstallPreparation {
    var normalized = config
    normalized.mcpServerPaths = config.mcpServerPaths.map {
        absolutePath(for: $0, relativeTo: workingDirectory)
    }

    let generatedToken: String?
    if tokenAuto {
        generatedToken = tokenGenerator()
        normalized.token = generatedToken
    } else {
        generatedToken = nil
    }

    return ServiceInstallPreparation(config: normalized, generatedToken: generatedToken)
}

public func stableExecutablePath(
    currentExecutablePath: String,
    fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
) -> String {
    let resolved = (currentExecutablePath as NSString).resolvingSymlinksInPath
    let optCandidates = [
        "/opt/homebrew/opt/apfel/bin/apfel",
        "/usr/local/opt/apfel/bin/apfel",
    ]

    if resolved.contains("/Cellar/apfel/") || resolved.contains("/opt/apfel/bin/apfel") {
        for candidate in optCandidates where fileExists(candidate) {
            return candidate
        }
    }

    return resolved
}

public func makeServiceLaunchAgentPlist(
    executablePath: String,
    servicePaths: ServicePaths,
    label: String = apfelServiceLabel
) throws -> String {
    let plist: [String: Any] = [
        "Label": label,
        "ProgramArguments": [executablePath, "service", "run"],
        "RunAtLoad": true,
        "KeepAlive": true,
        "WorkingDirectory": servicePaths.applicationSupportDirectory.path,
        "StandardOutPath": servicePaths.stdoutLog.path,
        "StandardErrorPath": servicePaths.stderrLog.path,
    ]
    let data = try PropertyListSerialization.data(
        fromPropertyList: plist,
        format: .xml,
        options: 0
    )
    guard let xml = String(data: data, encoding: .utf8) else {
        throw ApfelError.decodingFailure("Could not encode LaunchAgent plist as UTF-8")
    }
    return xml
}

public func serviceEndpoint(host: String, port: Int) -> String {
    "http://\(host):\(port)"
}

private func absolutePath(for path: String, relativeTo workingDirectory: URL) -> String {
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
    return URL(fileURLWithPath: path, relativeTo: workingDirectory).standardizedFileURL.path
}
