// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxRemoteWorkspace",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxRemoteWorkspace",
            targets: ["HmuxRemoteWorkspace"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxCore"),
        .package(path: "../HmuxRemoteDaemon"),
        .package(path: "../HmuxSettings"),
    ],
    targets: [
        .target(
            name: "HmuxRemoteWorkspace",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxCore", package: "HmuxCore"),
                .product(name: "HmuxRemoteDaemon", package: "HmuxRemoteDaemon"),
                .product(name: "HmuxSettings", package: "HmuxSettings"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxRemoteWorkspaceTests",
            dependencies: [
                "HmuxRemoteWorkspace",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ]
        ),
    ]
)
