// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxCloudImagePaste",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HmuxCloudImagePaste", targets: ["HmuxCloudImagePaste"]),
    ],
    targets: [
        .target(
            name: "HmuxCloudImagePaste",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxCloudImagePasteTests",
            dependencies: ["HmuxCloudImagePaste"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
