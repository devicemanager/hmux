// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxAgentDeliveryCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxAgentDeliveryCore",
            targets: ["HmuxAgentDeliveryCore"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxAgentDeliveryCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxAgentDeliveryCoreTests",
            dependencies: ["HmuxAgentDeliveryCore"]
        ),
    ]
)
