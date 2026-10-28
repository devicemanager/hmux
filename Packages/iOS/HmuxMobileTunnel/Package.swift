// swift-tools-version: 6.0

import PackageDescription

/// The phone's browser tunnel plumbing, independent of what carries the
/// bytes: a SOCKS5 proxy and loopback port forwards on the phone whose
/// connections are opened by a `SocksConnectBackend` (SSH `direct-tcpip`,
/// a paired Mac's irx lanes, or the phone's own network).
let package = Package(
    name: "HmuxMobileTunnel",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileTunnel",
            targets: ["HmuxMobileTunnel"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.81.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "HmuxMobileTunnel",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileTunnelTests",
            dependencies: [
                "HmuxMobileTunnel",
                .product(name: "NIOCore", package: "swift-nio"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ]
)
