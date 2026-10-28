// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxTerminalSharing",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HmuxTerminalSharing", targets: ["HmuxTerminalSharing"])],
    dependencies: [.package(path: "../../Shared/HmuxTerminalSizing")],
    targets: [
        .target(name: "HmuxTerminalSharing", dependencies: ["HmuxTerminalSizing"]),
        .testTarget(name: "HmuxTerminalSharingTests", dependencies: ["HmuxTerminalSharing", "HmuxTerminalSizing"]),
    ],
    swiftLanguageModes: [.v6]
)
