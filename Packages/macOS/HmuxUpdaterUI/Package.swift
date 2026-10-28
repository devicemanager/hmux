// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxUpdaterUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxUpdaterUI",
            targets: ["HmuxUpdaterUI"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxUpdater"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(
            name: "HmuxUpdaterUI",
            dependencies: [
                "HmuxFoundation",
                "HmuxUpdater",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxUpdaterUITests",
            dependencies: ["HmuxUpdaterUI"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
