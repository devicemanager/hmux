import Testing
@testable import HmuxSettings

@Test func markerFilesAreVariantAware() {
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.hmuxterm.app",
        environment: [:]
    ) == .stable)
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.hmuxterm.app.nightly",
        environment: [:]
    ) == .nightly(slug: nil))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.hmuxterm.app.rc",
        environment: [:]
    ) == .rc(slug: nil))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.hmuxterm.app.rc.my-feature",
        environment: [:]
    ) == .rc(slug: "my-feature"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.hmuxterm.app.debug.agent",
        environment: [:]
    ) == .dev(slug: "agent"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.hmuxterm.app.debug",
        environment: ["HMUX_TAG": "Issue 3542"]
    ) == .dev(slug: "issue-3542"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.hmuxterm.app.debug",
        environment: ["HMUX_TAG": "café"]
    ) == .dev(slug: "caf"))
}

@Test func defaultSocketPathsStayVariantScoped() {
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.hmuxterm.app",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/hmux.sock"
    ) == "/stable/hmux.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.hmuxterm.app.nightly",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/hmux.sock"
    ) == "/tmp/hmux-nightly.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.hmuxterm.app.rc",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/hmux.sock"
    ) == "/tmp/hmux-rc.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.hmuxterm.app.rc.candidate1",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/hmux.sock"
    ) == "/tmp/hmux-rc-candidate1.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.hmuxterm.app.staging.my-feature",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/hmux.sock"
    ) == "/tmp/hmux-staging-my-feature.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.hmuxterm.app.debug",
        environment: ["HMUX_TAG": "Issue 3542"],
        isDebugBuild: false,
        stableSocketPath: "/stable/hmux.sock"
    ) == "/tmp/hmux-debug-issue-3542.sock")
}
