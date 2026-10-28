// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxClientConfig",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxClientConfig",
            targets: ["HmuxClientConfig"]
        ),
    ],
    dependencies: [
        .package(path: "../HMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "HmuxClientConfig",
            dependencies: ["HMUXMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "HmuxClientConfigTests",
            dependencies: ["HmuxClientConfig"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
