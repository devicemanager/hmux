// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxExtensionSidebarExamples",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "HmuxExtensionSidebarExamples",
            targets: ["HmuxExtensionSidebarExamples"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/macOS/HmuxSidebarProviderKit"),
    ],
    targets: [
        .target(
            name: "HmuxExtensionSidebarExamples",
            dependencies: ["HmuxSidebarProviderKit"]
        ),
        .testTarget(
            name: "HmuxExtensionSidebarExamplesTests",
            dependencies: ["HmuxExtensionSidebarExamples"]
        ),
    ]
)
