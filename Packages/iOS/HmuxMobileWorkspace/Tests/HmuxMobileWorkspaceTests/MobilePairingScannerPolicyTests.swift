import Testing
@testable import HmuxMobileWorkspace

/// The pairing scanner accepts any hmux channel's pairing scheme (`hmux-ios://`
/// for release, `hmux-ios-dev://` for development). This guards the predicate
/// the UI hands to the camera service so a generic QR code (a URL, a Wi-Fi join
/// code) can never be mistaken for a pairing link, while cross-channel pairing
/// from inside the app still works.
@Suite struct MobilePairingScannerPolicyTests {
    @Test(arguments: [
        ("hmux-ios://attach?ticket=abc", true),
        ("hmux-ios://", true),
        ("hmux-ios-dev://attach?v=2&r=100.64.0.5:58465", true),
        ("hmux-ios-dev://", true),
        ("hmux://pair?v=1&host=100.64.0.5&port=4399&code=x&mac=m&exp=1", true),
        ("hmux://other", false),
        ("https://example.com", false),
        ("WIFI:S:net;;", false),
        ("", false),
    ])
    func acceptsOnlyPairingLinks(code: String, expected: Bool) {
        #expect(MobilePairingScannerPolicy.acceptsCode(code) == expected)
    }
}
