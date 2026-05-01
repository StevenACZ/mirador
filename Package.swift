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
        .executable(
            name: "mirador-host",
            targets: ["MiradorHost"]
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
        .executableTarget(
            name: "MiradorHost",
            dependencies: ["MiradorCore"]
        ),
        .testTarget(
            name: "MiradorCoreTests",
            dependencies: ["MiradorCore"]
        )
    ]
)
