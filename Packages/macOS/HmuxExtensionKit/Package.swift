// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxExtensionKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxExtensionKit",
            targets: ["HmuxExtensionKit"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxExtensionKit"
        ),
        .testTarget(
            name: "HmuxExtensionKitTests",
            dependencies: ["HmuxExtensionKit"]
        ),
    ]
)
