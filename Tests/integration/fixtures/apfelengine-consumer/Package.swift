// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ApfelEngineConsumer",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(name: "apfel", path: "../../../../"),
    ],
    targets: [
        .executableTarget(
            name: "apfelengine-consumer",
            dependencies: [
                .product(name: "ApfelEngine", package: "apfel"),
            ]
        )
    ]
)
