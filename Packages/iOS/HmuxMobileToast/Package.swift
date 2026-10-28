// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileToast",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileToast",
            targets: ["HmuxMobileToast"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../HmuxMobileSupport"),
    ],
    targets: [
        .target(
            name: "HmuxMobileToast",
            dependencies: [
                "HMUXMobileCore",
                "HmuxMobileSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileToastTests",
            dependencies: ["HmuxMobileToast"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
