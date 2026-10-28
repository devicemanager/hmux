// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxAgentSessionStore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxAgentSessionStore",
            targets: ["HmuxAgentSessionStore"]
        ),
    ],
    dependencies: [
        .package(path: "../HMUXAgentLaunch"),
    ],
    targets: [
        .target(
            name: "HmuxAgentSessionStore",
            dependencies: [
                .product(name: "HMUXAgentLaunch", package: "HMUXAgentLaunch"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxAgentSessionStoreTests",
            dependencies: ["HmuxAgentSessionStore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
