// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxTerminalSizing",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "HmuxTerminalSizing", targets: ["HmuxTerminalSizing"])],
    targets: [
        .target(name: "HmuxTerminalSizing"),
        .testTarget(name: "HmuxTerminalSizingTests", dependencies: ["HmuxTerminalSizing"])
    ],
    swiftLanguageModes: [.v6]
)
