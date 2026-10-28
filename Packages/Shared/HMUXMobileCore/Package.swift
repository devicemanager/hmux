// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HMUXMobileCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HMUXMobileCore",
            targets: ["HMUXMobileCore"]
        ),
    ],
    targets: [
        .target(
            name: "HMUXMobileCore",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HMUXMobileCoreTests",
            dependencies: ["HMUXMobileCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
