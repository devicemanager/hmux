// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxWindowing",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxWindowing",
            targets: ["HmuxWindowing"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxWindowing",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxWindowingTests",
            dependencies: ["HmuxWindowing"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
