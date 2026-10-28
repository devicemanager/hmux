// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxRemoteDaemon",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxRemoteDaemon",
            targets: ["HmuxRemoteDaemon"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxCore"),
    ],
    targets: [
        .target(
            name: "HmuxRemoteDaemon",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxCore", package: "HmuxCore"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxRemoteDaemonTests",
            dependencies: [
                "HmuxRemoteDaemon",
                .product(name: "HmuxCore", package: "HmuxCore"),
            ]
        ),
    ]
)
