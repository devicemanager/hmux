// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HmuxDiffComments",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "HmuxDiffComments",
            targets: ["HmuxDiffComments"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxDiffComments",
            path: "Sources/HmuxDiffComments"
        ),
    ]
)
