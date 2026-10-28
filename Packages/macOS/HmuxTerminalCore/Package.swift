// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxTerminalCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxTerminalCore",
            targets: ["HmuxTerminalCore"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HMUXDebugLog"),
        .package(path: "../../Shared/HmuxGhosttyKit"),
    ],
    targets: [
        .target(
            name: "HmuxTerminalCore",
            dependencies: [
                // The same libghostty the app links; the terminal core's
                // value types and FFI seam speak the ghostty C types
                // directly so no translation layer can drift from the
                // runtime.
                .product(name: "HmuxGhosttyKit", package: "HmuxGhosttyKit"),
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HMUXDebugLog", package: "HMUXDebugLog"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        // Test-only stand-in for the @_silgen_name libghostty symbol bound by
        // GhosttyRuntimeCInterop: SwiftPM cannot link the GhosttyKit macOS
        // archive (its binary lacks the lib prefix), so the test runner
        // satisfies the link with a stub. The app links the real GhosttyKit.
        .target(
            name: "GhosttyRuntimeTestStubs",
            path: "Tests/GhosttyRuntimeTestStubs"
        ),
        .testTarget(
            name: "HmuxTerminalCoreTests",
            dependencies: [
                "HmuxTerminalCore",
                "GhosttyRuntimeTestStubs",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ],
            // GhosttyKit's static lib carries C++ objects (glslang); the
            // standalone xctest bundle must link the C++ runtime itself.
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
    ]
)
