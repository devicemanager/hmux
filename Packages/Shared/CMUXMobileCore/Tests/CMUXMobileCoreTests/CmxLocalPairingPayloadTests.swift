import Foundation
import Testing
@testable import CMUXMobileCore

/// A local pairing QR must survive the Mac-to-phone round trip intact and
/// fail closed on anything stale, foreign, or incomplete.
@Suite struct CmxLocalPairingPayloadTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func payload(expiresIn seconds: TimeInterval = 300) -> CmxLocalPairingPayload {
        CmxLocalPairingPayload(
            hosts: ["100.64.0.42", "fd7a:115c:a1e0::2a"],
            port: 4399,
            pairingCode: "abc-DEF_123",
            macDeviceID: "0000c0de-b1d1-4e57-8a11-1c0ffee00042",
            macDisplayName: "Captain Brindlewick & co",
            expiresAt: now.addingTimeInterval(seconds)
        )
    }

    @Test func roundTripsEveryField() throws {
        let original = payload()
        let decoded = try CmxLocalPairingPayload(url: original.url, now: now)
        #expect(decoded == original)
    }

    @Test func rejectsExpiredCodes() {
        let stale = payload(expiresIn: -1)
        #expect(throws: CmxLocalPairingPayloadError.expired) {
            try CmxLocalPairingPayload(url: stale.url, now: now)
        }
    }

    @Test func rejectsForeignSchemes() throws {
        let url = try #require(URL(string: "cmux-ios-dev.cmux.app://pair?v=1&host=100.64.0.1&port=4399&code=x&mac=m&exp=1900000000"))
        #expect(throws: CmxLocalPairingPayloadError.invalidURL) {
            try CmxLocalPairingPayload(url: url, now: now)
        }
    }

    @Test func rejectsMissingCode() throws {
        let url = try #require(URL(string: "cmux-local://pair?v=1&host=100.64.0.1&port=4399&mac=m&exp=1900000000"))
        #expect(throws: CmxLocalPairingPayloadError.missingField("code")) {
            try CmxLocalPairingPayload(url: url, now: now)
        }
    }

    @Test func rejectsOutOfRangePorts() throws {
        let url = try #require(URL(string: "cmux-local://pair?v=1&host=100.64.0.1&port=70000&code=x&mac=m&exp=1900000000"))
        #expect(throws: CmxLocalPairingPayloadError.invalidPort(70000)) {
            try CmxLocalPairingPayload(url: url, now: now)
        }
    }
}
