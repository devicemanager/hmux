// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileWorkspace",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileWorkspace",
            targets: ["HmuxMobileWorkspace"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../HmuxMobileShellModel"),
    ],
    targets: [
        .target(
            name: "HmuxMobileWorkspace",
            dependencies: [
                "HMUXMobileCore",
                "HmuxMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileWorkspaceTests",
            dependencies: ["HmuxMobileWorkspace"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
