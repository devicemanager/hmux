// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobilePairedMac",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobilePairedMac",
            targets: ["HmuxMobilePairedMac"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "HmuxMobilePairedMac",
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
            name: "HmuxMobilePairedMacTests",
            dependencies: ["HmuxMobilePairedMac"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
