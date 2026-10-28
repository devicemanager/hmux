// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxCore",
            targets: ["HmuxCore"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxAgentDeliveryCore"),
    ],
    targets: [
        .target(
            name: "HmuxCore",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxAgentDeliveryCore", package: "HmuxAgentDeliveryCore"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxCoreTests",
            dependencies: ["HmuxCore"]
        ),
    ]
)
