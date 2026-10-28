// swift-tools-version: 6.0
import PackageDescription

// Deliberately dependency-free and platform-neutral: the prediction policy is
// the whole correctness story, so it builds and tests with plain `swift test`
// on Linux as well as in the macOS `swift-package-tests` CI job.
let package = Package(
    name: "HmuxTerminalPrediction",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "HmuxTerminalPrediction", targets: ["HmuxTerminalPrediction"])],
    targets: [
        .target(
            name: "HmuxTerminalPrediction",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HmuxTerminalPredictionTests",
            dependencies: ["HmuxTerminalPrediction"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
