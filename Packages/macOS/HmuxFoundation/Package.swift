// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxFoundation",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxFoundation",
            targets: ["HmuxFoundation"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxFoundationAtomicsC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "HmuxFoundation",
            dependencies: ["HmuxFoundationAtomicsC"],
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxFoundationTests",
            dependencies: ["HmuxFoundation"]
        ),
    ]
)
