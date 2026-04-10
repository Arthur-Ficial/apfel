// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "apfel",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "apfel", targets: ["apfel"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
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
        // Main executable — depends on ApfelCore + ApfelCLI + Hummingbird + FoundationModels
        .executableTarget(
            name: "apfel",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                "ApfelCore",
                "ApfelCLI",
                "CReadline",
            ],
            path: "Sources",
            exclude: ["Core", "CLI"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                ])
            ]
        ),
        // Test runner — pure Swift, no XCTest/Testing (Command Line Tools only)
        .executableTarget(
            name: "apfel-tests",
            dependencies: ["ApfelCore", "ApfelCLI"],
            path: "Tests/apfelTests"
        ),
    ]
)
