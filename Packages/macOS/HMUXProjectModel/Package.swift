// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HMUXProjectModel",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HMUXProjectModel",
            targets: ["HMUXProjectModel"]
        ),
        .executable(
            name: "hmux-project-dump",
            targets: ["HMUXProjectDump"]
        ),
    ],
    targets: [
        .target(
            name: "HMUXProjectModel"
        ),
        .executableTarget(
            name: "HMUXProjectDump",
            dependencies: ["HMUXProjectModel"]
        ),
        .testTarget(
            name: "HMUXProjectModelTests",
            dependencies: ["HMUXProjectModel"]
        ),
    ]
)
