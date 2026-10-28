// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileHost",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileHost",
            targets: ["HmuxMobileHost"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxAgentChat"),
    ],
    targets: [
        .target(
            name: "HmuxMobileHost",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HMUXMobileCore", package: "HMUXMobileCore"),
                .product(name: "HmuxAgentChat", package: "HmuxAgentChat"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileHostTests",
            dependencies: ["HmuxMobileHost"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
