// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HMUXDebugLog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HMUXDebugLog",
            targets: ["HMUXDebugLog"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HMUXDebugLog",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            path: "Sources/HMUXDebugLog"
        ),
        .testTarget(
            name: "HMUXDebugLogTests",
            dependencies: ["HMUXDebugLog"],
            path: "Tests/HMUXDebugLogTests"
        ),
    ]
)
