// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxCloudResizeCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HmuxCloudResizeCore", targets: ["HmuxCloudResizeCore"])
    ],
    targets: [
        .target(
            name: "HmuxCloudResizeCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
