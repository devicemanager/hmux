import Foundation
import Testing
#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// Account-free pairing is the only gate on the private-network route, so a
/// code must be single use and short lived, and only issued keys may pass.
@Suite struct MobileHostLocalPairingTests {
    private final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    private func makePairing(clock: Clock = Clock()) -> (MobileHostLocalPairing, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmux-local-pairing-\(UUID().uuidString)")
            .appendingPathComponent("devices.json")
        return (MobileHostLocalPairing(storeURL: url, now: { clock.now }), url)
    }

    @Test func codeRedeemsOnceForAWorkingKey() throws {
        let (pairing, _) = makePairing()
        let issued = pairing.issueCode()
        let redemption = try #require(pairing.redeem(code: issued.code, deviceName: "Test phone"))
        #expect(pairing.device(forKey: redemption.deviceKey)?.name == "Test phone")
        #expect(pairing.redeem(code: issued.code, deviceName: nil) == nil)
    }

    @Test func expiredCodeIsRejected() {
        let clock = Clock()
        let (pairing, _) = makePairing(clock: clock)
        let issued = pairing.issueCode()
        clock.now = issued.expiresAt.addingTimeInterval(1)
        #expect(pairing.redeem(code: issued.code, deviceName: nil) == nil)
    }

    @Test func repeatedWrongGuessesBurnTheCode() {
        let (pairing, _) = makePairing()
        let issued = pairing.issueCode()
        for _ in 0..<MobileHostLocalPairing.maximumFailedRedemptions {
            #expect(pairing.redeem(code: "wrong", deviceName: nil) == nil)
        }
        #expect(pairing.redeem(code: issued.code, deviceName: nil) == nil)
    }

    @Test func unknownAndRevokedKeysAreRejected() throws {
        let (pairing, _) = makePairing()
        #expect(pairing.device(forKey: "not-a-key") == nil)
        #expect(pairing.device(forKey: nil) == nil)
        let redemption = try #require(pairing.redeem(code: pairing.issueCode().code, deviceName: nil))
        #expect(pairing.revoke(deviceID: redemption.deviceID))
        #expect(pairing.device(forKey: redemption.deviceKey) == nil)
    }

    @Test func storeKeepsOnlyDigestsAndSurvivesReload() throws {
        let clock = Clock()
        let (pairing, url) = makePairing(clock: clock)
        let redemption = try #require(pairing.redeem(code: pairing.issueCode().code, deviceName: nil))
        let stored = try String(contentsOf: url, encoding: .utf8)
        #expect(!stored.contains(redemption.deviceKey))
        let reloaded = MobileHostLocalPairing(storeURL: url, now: { clock.now })
        #expect(reloaded.device(forKey: redemption.deviceKey)?.id == redemption.deviceID)
    }

    @Test func networkRouteServesOnlyProbeAndPairingWithoutAKey() throws {
        let (pairing, _) = makePairing()
        func request(_ method: String, key: String? = nil) -> MobileHostRPCRequest {
            MobileHostRPCRequest(
                id: 1,
                method: method,
                params: [:],
                auth: key.map { MobileHostRPCAuth(attachToken: nil, stackAccessToken: nil, deviceKey: $0) }
            )
        }
        #expect(MobileHostService.localDeviceAuthorizationError(for: request("mobile.host.status"), pairing: pairing) == nil)
        #expect(MobileHostService.localDeviceAuthorizationError(for: request("mobile.local.pair"), pairing: pairing) == nil)
        #expect(MobileHostService.localDeviceAuthorizationError(for: request("workspace.list"), pairing: pairing) != nil)
        let redemption = try #require(pairing.redeem(code: pairing.issueCode().code, deviceName: nil))
        #expect(MobileHostService.localDeviceAuthorizationError(
            for: request("workspace.list", key: redemption.deviceKey),
            pairing: pairing
        ) == nil)
    }
}
