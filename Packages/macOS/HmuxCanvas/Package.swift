// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxCanvas",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "HmuxCanvas",
            targets: ["HmuxCanvas"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxCanvas",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxCanvasTests",
            dependencies: [
                "HmuxCanvas",
            ]
        ),
    ]
)
