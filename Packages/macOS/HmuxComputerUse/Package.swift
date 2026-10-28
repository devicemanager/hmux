// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxComputerUse",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HmuxComputerUse", targets: ["HmuxComputerUse"])],
    dependencies: [
        .package(path: "../HmuxControlSocket"),
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxSettings")
    ],
    targets: [
        .target(
            name: "HmuxComputerUse",
            dependencies: ["HmuxControlSocket", "HmuxFoundation", "HmuxSettings"],
            // Lane A preserves the executable target's language mode.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "HmuxComputerUseTests", dependencies: ["HmuxComputerUse"])
    ]
)
