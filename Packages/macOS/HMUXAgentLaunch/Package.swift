// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HMUXAgentLaunch",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HMUXAgentLaunch",
            targets: ["HMUXAgentLaunch"]
        ),
    ],
    targets: [
        .target(
            name: "HMUXAgentLaunch"
        ),
        .testTarget(
            name: "HMUXAgentLaunchTests",
            dependencies: ["HMUXAgentLaunch"]
        ),
    ]
)
