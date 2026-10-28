// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxCloudBannerCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxCloudBannerCore",
            targets: ["HmuxCloudBannerCore"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxCloudBannerCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxCloudBannerCoreTests",
            dependencies: ["HmuxCloudBannerCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
