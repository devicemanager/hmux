// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileBrowserStream",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxMobileBrowserStream", targets: ["HmuxMobileBrowserStream"]),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../HmuxMobileSupport"),
    ],
    targets: [
        .target(
            name: "HmuxMobileBrowserStream",
            dependencies: ["HMUXMobileCore", "HmuxMobileSupport"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileBrowserStreamTests",
            dependencies: ["HmuxMobileBrowserStream", "HMUXMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
