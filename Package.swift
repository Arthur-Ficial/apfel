// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "apfel",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ApfelCore", targets: ["ApfelCore"]),
        // Preview: may change in minor releases until it has a shipped
        // consumer (STABILITY.md, docs/swift-library.md).
        .library(name: "ApfelEngine", targets: ["ApfelEngine"]),
        .executable(name: "apfel", targets: ["apfel"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.6"),
        // lesbar: shared on-device file -> text (Vision OCR + PDFKit) + image
        // classification. Owns the -f/pipe extraction stack so it is maintained once
        // (also consumed by auge). Framework-bearing target used only by the executable.
        .package(url: "https://github.com/Arthur-Ficial/lesbar.git", from: "0.3.0"),
    ],
    targets: [
        .systemLibrary(
            name: "CReadline",
            path: "Sources/CReadline"
        ),
        // Pure-logic library — no FoundationModels, testable
        .target(
            name: "ApfelCore",
            dependencies: [],
            path: "Sources/Core"
        ),
        // CLI argument parsing — depends on ApfelCore for ContextStrategy
        .target(
            name: "ApfelCLI",
            dependencies: ["ApfelCore"],
            path: "Sources/CLI"
        ),
        // Reusable generation engine — FoundationModels + ApfelCore, print-free.
        // Consumed by the apfel executable and downstream library consumers.
        .target(
            name: "ApfelEngine",
            dependencies: ["ApfelCore"],
            path: "Sources/Engine"
        ),
        // Main executable — depends on ApfelCore + ApfelCLI + Hummingbird + FoundationModels
        .executableTarget(
            name: "apfel",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                "ApfelCore",
                "ApfelCLI",
                "ApfelEngine",
                "CReadline",
                .product(name: "Lesbar", package: "lesbar"),
                .product(name: "LesbarCore", package: "lesbar"),
            ],
            path: "Sources",
            exclude: ["Core", "CLI", "Engine"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                    // SDK stamp (#521): the macOS 27 runtime keys typed
                    // LanguageModelError and other 27 behaviour on the
                    // binary's LC_BUILD_VERSION sdk. SwiftPM's default build
                    // system stamps sdk 26.0 even on the 27 SDK (homebrew-core
                    // builds that way), so pin it: floor 26.0, sdk 27.0 - the
                    // minimum SDK check-toolchain requires. Raise both together.
                    "-Xlinker", "-platform_version",
                    "-Xlinker", "macos",
                    "-Xlinker", "26.0",
                    "-Xlinker", "27.0",
                ])
            ]
        ),
        // Test runner — pure Swift, no XCTest/Testing (Command Line Tools only)
        .executableTarget(
            name: "apfel-tests",
            dependencies: ["ApfelCore", "ApfelCLI", "ApfelEngine"],
            path: "Tests/apfelTests"
        ),
        .executableTarget(
            name: "apfelcore-context-strategies-example",
            dependencies: ["ApfelCore"],
            path: "Examples/ContextStrategies"
        ),
        .executableTarget(
            name: "apfelcore-openai-types-example",
            dependencies: ["ApfelCore"],
            path: "Examples/OpenAITypes"
        ),
        .executableTarget(
            name: "apfelcore-tool-calling-example",
            dependencies: ["ApfelCore"],
            path: "Examples/ToolCalling"
        ),
        .executableTarget(
            name: "apfelcore-error-handling-example",
            dependencies: ["ApfelCore"],
            path: "Examples/ErrorHandling"
        ),
        .executableTarget(
            name: "apfelcore-mcp-protocol-example",
            dependencies: ["ApfelCore"],
            path: "Examples/MCPProtocol"
        ),
    ]
)
