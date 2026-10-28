// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxNotifications",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxNotifications",
            targets: ["HmuxNotifications"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxNotifications",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxNotificationsTests",
            dependencies: ["HmuxNotifications"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
