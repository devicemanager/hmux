// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxGit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxGit",
            targets: ["HmuxGit"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../../Shared/HmuxAgentChat"),
        .package(path: "../../Shared/HMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "HmuxGit",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxAgentChat", package: "HmuxAgentChat"),
                .product(name: "HMUXMobileCore", package: "HMUXMobileCore"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxGitTests",
            dependencies: ["HmuxGit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
