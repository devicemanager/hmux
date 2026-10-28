// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileChanges",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileChanges",
            targets: ["HmuxMobileChanges"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxMobileChanges",
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileChangesTests",
            dependencies: ["HmuxMobileChanges"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
