// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSidebarGit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSidebarGit",
            targets: ["HmuxSidebarGit"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxGit"),
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HmuxSidebarGit",
            dependencies: [
                .product(name: "HmuxGit", package: "HmuxGit"),
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxSidebarGitTests",
            dependencies: [
                "HmuxSidebarGit",
                .product(name: "HmuxGit", package: "HmuxGit"),
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
