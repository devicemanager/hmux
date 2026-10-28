// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxControlSocket",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxControlSocket",
            targets: ["HmuxControlSocket"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxCore"),
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxSettings"),
    ],
    targets: [
        .target(
            name: "HmuxControlSocketAtomicsC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "HmuxControlSocket",
            dependencies: [
                .product(name: "HmuxCore", package: "HmuxCore"),
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxSettings", package: "HmuxSettings"),
                "HmuxControlSocketAtomicsC",
            ],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxControlSocketTests",
            dependencies: [
                "HmuxControlSocket",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxSettings", package: "HmuxSettings"),
            ]
        ),
    ]
)
