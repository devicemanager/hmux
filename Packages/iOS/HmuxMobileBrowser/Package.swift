// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileBrowser",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileBrowser",
            targets: ["HmuxMobileBrowser"]
        ),
    ],
    dependencies: [
        // Localized-string helpers (`L10n`). `HmuxMobileSupport` is a leaf with
        // no dependencies, so the browser package stays low in the DAG.
        .package(path: "../HmuxMobileSupport"),
    ],
    targets: [
        // A self-contained, phone-local browser surface. P1 browser state never
        // touches the Mac, so this package sits low in the DAG: it depends only
        // on the leaf `HmuxMobileSupport` and links Foundation/WebKit/SwiftUI.
        .target(
            name: "HmuxMobileBrowser",
            dependencies: [
                "HmuxMobileSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileBrowserTests",
            dependencies: ["HmuxMobileBrowser"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
