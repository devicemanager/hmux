// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSyncStore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSyncStore",
            targets: ["HmuxSyncStore"]
        ),
    ],
    dependencies: [
        .package(path: "../HMUXMobileCore"),
        .package(path: "../../iOS/HmuxMobilePairedMac"),
        .package(path: "../../iOS/HmuxMobileShellModel"),
    ],
    targets: [
        .target(
            name: "HmuxSyncStore",
            dependencies: [
                "HMUXMobileCore",
                "HmuxMobilePairedMac",
                "HmuxMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxSyncStoreTests",
            dependencies: ["HmuxSyncStore", "HmuxMobilePairedMac", "HMUXMobileCore", "HmuxMobileShellModel"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
