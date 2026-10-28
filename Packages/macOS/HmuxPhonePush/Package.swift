// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxPhonePush",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HmuxPhonePush", targets: ["HmuxPhonePush"]),
    ],
    dependencies: [
        .package(path: "../../Shared/HmuxAuthRuntime"),
    ],
    targets: [
        .target(
            name: "HmuxPhonePush",
            dependencies: ["HmuxAuthRuntime"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxPhonePushTests",
            dependencies: ["HmuxPhonePush"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
