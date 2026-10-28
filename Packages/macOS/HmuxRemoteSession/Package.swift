// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxRemoteSession",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxRemoteSession",
            targets: ["HmuxRemoteSession"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxCore"),
        .package(path: "../HmuxRemoteDaemon"),
        .package(path: "../HmuxRemoteWorkspace"),
        .package(path: "../HMUXDebugLog"),
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "HmuxRemoteSession",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxCore", package: "HmuxCore"),
                .product(name: "HmuxRemoteDaemon", package: "HmuxRemoteDaemon"),
                .product(name: "HmuxRemoteWorkspace", package: "HmuxRemoteWorkspace"),
                .product(name: "HMUXDebugLog", package: "HMUXDebugLog"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxRemoteSessionTests",
            dependencies: [
                "HmuxRemoteSession",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxCore", package: "HmuxCore"),
                .product(name: "HmuxRemoteDaemon", package: "HmuxRemoteDaemon"),
                .product(name: "HmuxRemoteWorkspace", package: "HmuxRemoteWorkspace"),
                .product(name: "Bonsplit", package: "bonsplit"),
            ]
        ),
    ]
)
