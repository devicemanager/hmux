// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxWorkspacePresence",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "HmuxWorkspacePresence", targets: ["HmuxWorkspacePresence"])],
    dependencies: [.package(path: "../HMUXMobileCore")],
    targets: [
        .target(name: "HmuxWorkspacePresence", dependencies: ["HMUXMobileCore"]),
        .testTarget(name: "HmuxWorkspacePresenceTests", dependencies: ["HmuxWorkspacePresence", "HMUXMobileCore"])
    ],
    swiftLanguageModes: [.v6]
)
