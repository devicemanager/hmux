// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileTerminalKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileTerminalKit",
            targets: ["HmuxMobileTerminalKit"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "HmuxMobileTerminalKit",
            dependencies: [
                "HMUXMobileCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileTerminalKitTests",
            dependencies: ["HmuxMobileTerminalKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
