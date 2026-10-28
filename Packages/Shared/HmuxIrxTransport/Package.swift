// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxIrxTransport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxIrxTransport",
            targets: ["HmuxIrxTransport"]
        ),
    ],
    dependencies: [
        .package(path: "../HMUXMobileCore"),
        // Grant claims/verifier and terminal-envelope codecs are consumed as
        // stable data contracts; none of the legacy runtime machinery is used.
        .package(path: "../HmuxIrohTransport"),
        .package(
            url: "https://github.com/manaflow-ai/iroh-ffi.git",
            exact: "1.2.0-hmux.1.ios17"
        ),
    ],
    targets: [
        .target(
            name: "HmuxIrxTransport",
            dependencies: [
                "HMUXMobileCore",
                "HmuxIrohTransport",
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
            name: "HmuxIrxTransportTests",
            dependencies: [
                "HmuxIrxTransport",
                "HMUXMobileCore",
                "HmuxIrohTransport",
                .product(name: "IrohLib", package: "iroh-ffi"),
            ],
            resources: [
                .copy("V2/Fixtures"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
