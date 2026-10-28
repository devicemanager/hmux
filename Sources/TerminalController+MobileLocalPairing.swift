import HMUXMobileCore
import Foundation

/// Local automation socket commands for account-free phone pairing.
///
/// These run only on the Mac's own socket (`hmux rpc ...`). The phone-facing
/// RPC surface can redeem a code but never mint one or manage paired devices.
extension TerminalController {
    /// Issues a single-use pairing code and returns the QR URL plus its parts.
    nonisolated func v2MobileLocalPairingCreate() -> V2CallResult {
        let issued = v2MainSync { MobileHostService.shared.issueLocalPairingPayload() }
        switch issued {
        case let .success(payload):
            return .ok([
                "url": payload.url.absoluteString,
                "hosts": payload.hosts,
                "port": payload.port,
                "pairing_code": payload.pairingCode,
                "mac_device_id": payload.macDeviceID,
                "expires_at": ISO8601DateFormatter().string(from: payload.expiresAt),
            ])
        case .failure(.listenerNotRunning):
            return .err(
                code: "unavailable",
                message: "The Tailscale pairing listener is not running. Turn on iOS pairing in Settings > Mobile.",
                data: nil
            )
        case .failure(.noTailscaleAddress):
            return .err(
                code: "unavailable",
                message: "This Mac has no Tailscale address. Connect Tailscale and try again.",
                data: nil
            )
        }
    }

    nonisolated func v2MobileLocalDevicesList() -> V2CallResult {
        let formatter = ISO8601DateFormatter()
        let devices = MobileHostLocalPairing.shared.pairedDevices().map { device in
            [
                "id": device.id,
                "name": device.name,
                "paired_at": formatter.string(from: device.pairedAt),
            ]
        }
        return .ok(["devices": devices])
    }

    /// Params: `{ "id": String }`. Takes effect on the phone's next request.
    nonisolated func v2MobileLocalDevicesRevoke(params: [String: Any]) -> V2CallResult {
        guard let id = (params["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else {
            return .err(code: "invalid_params", message: "Missing device id", data: nil)
        }
        guard MobileHostLocalPairing.shared.revoke(deviceID: id) else {
            return .err(code: "not_found", message: "No paired device with that id", data: nil)
        }
        return .ok(["revoked": id])
    }
}
