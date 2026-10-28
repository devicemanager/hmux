// swift-tools-version: 6.0

import PackageDescription

// One harness-neutral model for a question an agent asks a person
// (plans/hmux-next/agent-questions.md): Claude Code's AskUserQuestion, a
// Codex user-input request, a generic ACP interactive permission and a
// Chief question in Home all map to `AgentQuestion`, and every answer is
// encoded back into the asking harness's own shape. Foundation only, so the
// Mac app, the iOS app and tests share it. The JSON fixtures under
// Sources/HmuxAgentQuestion/Fixtures are plain data: the Swift tests, the UI
// Gallery and the web gallery read the same files.
let package = Package(
    name: "HmuxAgentQuestion",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxAgentQuestion", targets: ["HmuxAgentQuestion"]),
    ],
    targets: [
        .target(
            name: "HmuxAgentQuestion",
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HmuxAgentQuestionTests",
            dependencies: ["HmuxAgentQuestion"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
