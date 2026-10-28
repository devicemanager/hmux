// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxCanvasUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxCanvasUI",
            targets: ["HmuxCanvasUI"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxCanvas"),
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HmuxCanvasUI",
            dependencies: [
                "HmuxCanvas",
                "HmuxFoundation",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxCanvasUITests",
            dependencies: [
                "HmuxCanvasUI",
            ]
        ),
    ]
)
