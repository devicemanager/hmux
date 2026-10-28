// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxAppKitSupportUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxAppKitSupportUI",
            targets: ["HmuxAppKitSupportUI"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxWorkspaces"),
    ],
    targets: [
        .target(
            name: "HmuxAppKitSupportUI",
            dependencies: [
                "HmuxFoundation",
                "HmuxWorkspaces",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxAppKitSupportUITests",
            dependencies: ["HmuxAppKitSupportUI"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
