// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxTestSupport",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxTestSupport",
            targets: ["HmuxTestSupport"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxTestSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxTestSupportTests",
            dependencies: ["HmuxTestSupport"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
