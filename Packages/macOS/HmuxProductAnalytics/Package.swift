// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxProductAnalytics",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxProductAnalytics",
            targets: ["HmuxProductAnalytics"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "HmuxProductAnalytics",
            dependencies: ["HMUXMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxProductAnalyticsTests",
            dependencies: ["HmuxProductAnalytics", "HMUXMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
