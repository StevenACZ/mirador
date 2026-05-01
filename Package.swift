// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Mirador",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "MiradorCore",
            targets: ["MiradorCore"]
        ),
        .library(
            name: "MiradorClient",
            targets: ["MiradorClient"]
        ),
        .library(
            name: "MiradorHost",
            targets: ["MiradorHost"]
        ),
        .executable(
            name: "mirador-host",
            targets: ["MiradorHostExecutable"]
        )
    ],
    targets: [
        .target(
            name: "MiradorCore"
        ),
        .target(
            name: "MiradorClient",
            dependencies: ["MiradorCore"]
        ),
        .target(
            name: "MiradorHost",
            dependencies: ["MiradorCore"]
        ),
        .executableTarget(
            name: "MiradorHostExecutable",
            dependencies: ["MiradorHost"]
        ),
        .testTarget(
            name: "MiradorCoreTests",
            dependencies: ["MiradorCore"]
        )
    ]
)
