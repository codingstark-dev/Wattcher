// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Wattcher",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WattcherCore", targets: ["WattcherCore"]),
        .executable(name: "Wattcher", targets: ["Wattcher"]),
    ],
    targets: [
        .target(
            name: "WattcherSystem",
            publicHeadersPath: "include"
        ),
        .target(
            name: "WattcherCore",
            dependencies: ["WattcherSystem"],
            exclude: ["AGENTS.md"]
        ),
        .executableTarget(
            name: "Wattcher",
            dependencies: ["WattcherCore"],
            exclude: ["AGENTS.md"]
        ),
        .testTarget(
            name: "WattcherCoreTests",
            dependencies: ["WattcherCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
