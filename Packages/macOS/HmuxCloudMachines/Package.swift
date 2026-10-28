// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxCloudMachines",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HmuxCloudMachines", targets: ["HmuxCloudMachines"])],
    targets: [
        .target(name: "HmuxCloudMachines"),
        .testTarget(name: "HmuxCloudMachinesTests", dependencies: ["HmuxCloudMachines"])
    ]
)
