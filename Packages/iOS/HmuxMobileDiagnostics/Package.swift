// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileDiagnostics",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileDiagnostics",
            targets: ["HmuxMobileDiagnostics"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxMobileDiagnostics",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileDiagnosticsTests",
            dependencies: ["HmuxMobileDiagnostics"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
