import HMUXMobileCore
internal import HmuxMobileDiagnostics
import HmuxMobileRPC
import HmuxMobileShellModel
import HmuxMobileSupport
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Account-free pairing with a Mac on the owner's tailnet.
///
/// A `hmux://pair` code carries the Mac's Tailscale addresses and a
/// one-time pairing code. The phone redeems the code for a per-phone device
/// key, stores it for those exact endpoints, then pairs through the manual
/// Tailscale route, whose requests carry the key instead of an account token.
@MainActor
extension MobileShellComposite {
    /// The Mac's reply to `mobile.local.pair`.
    struct LocalPairingRedemption: Decodable, Sendable {
        let deviceID: String
        let deviceKey: String
        let macDeviceID: String
        let macDisplayName: String?

        enum CodingKeys: String, CodingKey {
            case deviceID = "device_id"
            case deviceKey = "device_key"
            case macDeviceID = "mac_device_id"
            case macDisplayName = "mac_display_name"
        }
    }

    func connectLocalPairingURL(_ rawURL: String) async -> MobilePairingURLConnectionResult {
        let payload: CmxLocalPairingPayload
        do {
            guard let url = URL(string: rawURL) else { throw CmxLocalPairingPayloadError.invalidURL }
            payload = try CmxLocalPairingPayload(url: url, now: runtime?.now() ?? Date())
        } catch CmxLocalPairingPayloadError.expired {
            failLocalPairing(L10n.string(
                "mobile.localPairing.expired",
                defaultValue: "This pairing code has expired. Create a new one on your Mac and scan it again."
            ))
            return .failed
        } catch {
            failLocalPairing(L10n.string(
                "mobile.localPairing.invalid",
                defaultValue: "This isn't a valid local pairing code. It must name your Mac's Tailscale address."
            ))
            return .failed
        }
        guard let runtime, let keys = runtime.localDeviceKeys else {
            failLocalPairing(L10n.string(
                "mobile.localPairing.unsupported",
                defaultValue: "This version of the app can't pair without an account."
            ))
            return .failed
        }

        for host in payload.hosts {
            let redemption: LocalPairingRedemption
            do {
                redemption = try await redeemLocalPairingCode(payload, host: host, runtime: runtime)
            } catch MobileShellConnectionError.rpcError(let code, _) where code == "invalid_pairing_code" {
                failLocalPairing(L10n.string(
                    "mobile.localPairing.rejected",
                    defaultValue: "Your Mac rejected this pairing code. It may already be used. Create a new one and scan it again."
                ))
                return .failed
            } catch {
                // The next address may still reach the Mac (IPv4 vs IPv6).
                MobileDebugLog.shared.append("pairing.local.redeem_failed error_type=\(type(of: error))")
                continue
            }
            // A different Mac answering the address must not receive a key
            // binding meant for the one that showed the code.
            guard cmxCanonicalDeviceID(redemption.macDeviceID) == payload.macDeviceID else {
                failLocalPairing(L10n.string(
                    "mobile.localPairing.wrongMac",
                    defaultValue: "A different Mac answered at this address. Check Tailscale and try again."
                ))
                return .failed
            }
            do {
                try keys.save(
                    CmxLocalDeviceCredential(
                        deviceKey: redemption.deviceKey,
                        deviceID: redemption.deviceID,
                        macDeviceID: redemption.macDeviceID,
                        macDisplayName: redemption.macDisplayName ?? payload.macDisplayName
                    ),
                    hosts: payload.hosts,
                    port: payload.port
                )
            } catch {
                failLocalPairing(L10n.string(
                    "mobile.localPairing.keychainFailed",
                    defaultValue: "The pairing key couldn't be saved to this device's Keychain."
                ))
                return .failed
            }
            return await connectManualHostResult(
                name: redemption.macDisplayName ?? payload.macDisplayName ?? host,
                host: host,
                port: payload.port
            )
        }
        failLocalPairing(L10n.string(
            "mobile.localPairing.unreachable",
            defaultValue: "Couldn't reach your Mac over Tailscale. Make sure Tailscale is on for both devices."
        ))
        return .failed
    }

    private func redeemLocalPairingCode(
        _ payload: CmxLocalPairingPayload,
        host: String,
        runtime: any MobileSyncRuntime
    ) async throws -> LocalPairingRedemption {
        let route = try Self.manualHostRoute(host: host, port: payload.port)
        let client = MobileCoreRPCClient(
            runtime: runtime,
            route: route,
            ticket: try syntheticManualHostTicket(
                displayName: payload.macDisplayName ?? host,
                macDeviceID: "manual-local-pairing",
                route: route
            ),
            userTailscalePairingAuthorization: try CmxUserTailscalePairingAuthorization(
                host: host,
                port: payload.port
            ),
            connectAttemptRegistry: connectAttemptRegistry,
            sessionPurpose: .probe
        )
        defer { Task { await client.disconnect() } }
        let request = try MobileCoreRPCClient.requestData(
            method: CmxLocalPairing.pairMethod,
            params: [
                "pairing_code": payload.pairingCode,
                "device_name": Self.localPairingDeviceName,
            ]
        )
        let data = try await client.sendRequest(
            request,
            timeoutNanoseconds: runtime.pairingRequestTimeoutNanoseconds
        )
        return try JSONDecoder().decode(LocalPairingRedemption.self, from: data)
    }

    private static var localPairingDeviceName: String {
        #if canImport(UIKit)
        UIDevice.current.name
        #else
        Host.current().localizedName ?? "hmux"
        #endif
    }
}
