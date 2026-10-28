// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileRPC",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileRPC",
            targets: ["HmuxMobileRPC"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxTerminalSizing"),
        .package(path: "../HmuxMobileShellModel"),
        .package(path: "../HmuxMobileSupport"),
    ],
    targets: [
        .target(
            name: "HmuxMobileRPC",
            dependencies: [
                "HMUXMobileCore",
                "HmuxTerminalSizing",
                "HmuxMobileShellModel",
                "HmuxMobileSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileRPCTests",
            dependencies: [
                "HmuxMobileRPC",
                "HMUXMobileCore",
                "HmuxMobileShellModel",
                "HmuxTerminalSizing",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
