// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSwiftRenderUI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSwiftRenderUI",
            targets: ["HmuxSwiftRenderUI"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxSwiftRender"),
        .package(path: "../HmuxSettings"),
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HmuxSwiftRenderUI",
            dependencies: [
                .product(name: "HmuxSwiftRender", package: "HmuxSwiftRender"),
                .product(name: "HmuxSettings", package: "HmuxSettings"),
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "HmuxSwiftRenderUITests",
            dependencies: ["HmuxSwiftRenderUI"]
        ),
        // Dev-only GUI lab for iterating on the reorderable drag interaction
        // without an app build. Run: swift run reorder-lab
        .executableTarget(
            name: "reorder-lab",
            dependencies: ["HmuxSwiftRenderUI"]
        ),
    ]
)
