// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileTransport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileTransport",
            targets: ["HmuxMobileTransport"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../HmuxMobileDiagnostics"),
    ],
    targets: [
        .target(
            name: "HmuxMobileTransport",
            dependencies: ["HMUXMobileCore", "HmuxMobileDiagnostics"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileTransportTests",
            dependencies: ["HmuxMobileTransport", "HMUXMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
