// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSimulatorStreamKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSimulatorStreamKit",
            targets: ["HmuxSimulatorStreamKit"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxSimulatorStreamKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HmuxSimulatorStreamKitTests",
            dependencies: ["HmuxSimulatorStreamKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
