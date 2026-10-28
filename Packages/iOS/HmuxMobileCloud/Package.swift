// swift-tools-version: 6.0

import PackageDescription

// Domain package for hmux Cloud on the phone: the `/api/vm` client, the
// device's WireGuard identity, the wg-quick config the in-process tunnel
// consumes, and the session controller that owns tunnel and link lifecycle.
//
// It deliberately does NOT depend on `HmuxTerminalClient`: the Rust client
// arrives as a prebuilt binary, and this package must build and test without
// it. The transport is a protocol seam (`CloudTerminalTransport.swift`) that
// the composition root satisfies with the Kit.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "HmuxMobileCloud",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxMobileCloud", targets: ["HmuxMobileCloud"]),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "HmuxMobileCloud",
            dependencies: ["HMUXMobileCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HmuxMobileCloudTests",
            dependencies: ["HmuxMobileCloud"],
            swiftSettings: swiftSettings
        ),
    ]
)
