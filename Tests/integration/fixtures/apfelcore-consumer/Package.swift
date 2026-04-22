// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ApfelCoreConsumer",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(name: "apfel", path: "../../../../"),
    ],
    targets: [
        .executableTarget(
            name: "apfelcore-consumer",
            dependencies: [
                .product(name: "ApfelCore", package: "apfel"),
            ]
        )
    ]
)
