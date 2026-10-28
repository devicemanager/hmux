import Testing
@testable import HmuxFoundation

@Suite struct SentryBuildIdentityPolicyTests {
    private static let base = "com.hmuxterm.app"

    @Test(arguments: [
        "com.hmuxterm.app",
        "com.hmuxterm.app.nightly",
        "com.hmuxterm.app.nightly.rc1",
        "com.hmuxterm.app.rc",
        "com.hmuxterm.app.rc.candidate1",
        "com.hmuxterm.app.staging",
        "com.hmuxterm.app.debug",
        "com.hmuxterm.app.debug.snmsc",
        " com.hmuxterm.app "
    ])
    func allowsHmuxBuildIdentities(_ bundleIdentifier: String) {
        #expect(SentryBuildIdentityPolicy(
            bundleIdentifier: bundleIdentifier,
            trustedBaseBundleIdentifier: Self.base
        ).allowsTelemetry)
    }

    @Test(arguments: [
        "mosaic.com.emergent.app",
        "com.emergent.mosaic",
        "com.hmuxterm.application",
        "com.hmuxterm",
        "org.example.hmux",
        "",
        " "
    ])
    func deniesForeignBuildIdentities(_ bundleIdentifier: String) {
        #expect(!SentryBuildIdentityPolicy(
            bundleIdentifier: bundleIdentifier,
            trustedBaseBundleIdentifier: Self.base
        ).allowsTelemetry)
    }

    @Test func deniesMissingBuildIdentity() {
        #expect(!SentryBuildIdentityPolicy(
            bundleIdentifier: nil,
            trustedBaseBundleIdentifier: Self.base
        ).allowsTelemetry)
    }
}
