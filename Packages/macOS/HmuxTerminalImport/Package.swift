// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxTerminalImport",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxTerminalImport",
            targets: ["HmuxTerminalImport"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxTerminalImport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxTerminalImportTests",
            dependencies: ["HmuxTerminalImport"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
