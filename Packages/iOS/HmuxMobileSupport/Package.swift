// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileSupport",
            targets: ["HmuxMobileSupport"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxMobileSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileSupportTests",
            dependencies: ["HmuxMobileSupport"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
