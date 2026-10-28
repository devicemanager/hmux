// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSettings",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSettings",
            targets: ["HmuxSettings"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxCore"),
    ],
    targets: [
        .target(
            name: "HmuxSettings",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxCore", package: "HmuxCore"),
            ],
            resources: [
                .copy("Resources/CustomSidebarTemplates"),
            ]
        ),
        .testTarget(
            name: "HmuxSettingsTests",
            dependencies: ["HmuxSettings"]
        ),
    ]
)
