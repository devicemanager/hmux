// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxSidebarProviderKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSidebarProviderKit",
            targets: ["HmuxSidebarProviderKit"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HmuxSidebarProviderKit",
            dependencies: ["HmuxFoundation"]
        ),
    ]
)
