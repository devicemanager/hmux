// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxCloudTunnelCore",
    platforms: [
        .macOS(.v14),
        // The iOS Cloud VPN extension (ios/CloudVPN) runs the same lifecycle.
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "HmuxCloudTunnelCore",
            targets: ["HmuxCloudTunnelCore"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxCloudTunnelCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(name: "HmuxCloudTunnelCoreTests", dependencies: ["HmuxCloudTunnelCore"]),
    ]
)
