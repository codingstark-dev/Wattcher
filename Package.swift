// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Wattcher",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WattcherCore", targets: ["WattcherCore"]),
        .executable(name: "Wattcher", targets: ["Wattcher"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
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
            dependencies: [
                "WattcherCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            exclude: ["AGENTS.md"]
        ),
        .testTarget(
            name: "WattcherCoreTests",
            dependencies: ["WattcherCore"]
        ),
        .testTarget(
            name: "WattcherUITests",
            dependencies: ["Wattcher"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
