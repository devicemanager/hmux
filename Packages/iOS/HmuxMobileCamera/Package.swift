// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileCamera",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileCamera",
            targets: ["HmuxMobileCamera"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxMobileCamera",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileCameraTests",
            dependencies: ["HmuxMobileCamera"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
