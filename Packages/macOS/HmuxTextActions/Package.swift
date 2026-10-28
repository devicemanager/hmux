// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxTextActions",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxTextActions",
            targets: ["HmuxTextActions"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxTextActions",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxTextActionsTests",
            dependencies: ["HmuxTextActions"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
