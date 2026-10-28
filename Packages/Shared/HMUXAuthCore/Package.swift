// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HMUXAuthCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HMUXAuthCore",
            targets: ["HMUXAuthCore"]
        ),
    ],
    targets: [
        .target(
            name: "HMUXAuthCore"
        ),
        .testTarget(
            name: "HMUXAuthCoreTests",
            dependencies: ["HMUXAuthCore"]
        ),
    ]
)
