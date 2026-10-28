// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxIrohTransport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxIrohTransport",
            targets: ["HmuxIrohTransport"]
        ),
    ],
    dependencies: [
        .package(path: "../HMUXMobileCore"),
        .package(
            url: "https://github.com/manaflow-ai/iroh-ffi.git",
            exact: "1.2.0-hmux.1.ios17"
        ),
    ],
    targets: [
        .target(
            name: "HmuxIrohTransport",
            dependencies: [
                "HMUXMobileCore",
                .product(name: "IrohLib", package: "iroh-ffi"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ],
            linkerSettings: [
                .linkedFramework("Security"),
            ]
        ),
        .testTarget(
            name: "HmuxIrohTransportTests",
            dependencies: [
                "HmuxIrohTransport",
                "HMUXMobileCore",
                .product(name: "IrohLib", package: "iroh-ffi"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
