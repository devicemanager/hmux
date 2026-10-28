// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxFilePreviewCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxFilePreviewCore",
            targets: ["HmuxFilePreviewCore"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxFilePreviewCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxFilePreviewCoreTests",
            dependencies: ["HmuxFilePreviewCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
