// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileShellModel",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileShellModel",
            targets: ["HmuxMobileShellModel"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxTerminalSizing"),
    ],
    targets: [
        .target(
            name: "HmuxMobileShellModel",
            dependencies: [
                "HMUXMobileCore",
                "HmuxTerminalSizing",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileShellModelTests",
            dependencies: ["HmuxMobileShellModel", "HmuxTerminalSizing"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
