import Foundation

/// Wire constants for account-free local pairing over a private network
/// (Tailscale) TCP route.
///
/// A phone redeems a short-lived, single-use pairing code once through
/// ``pairMethod`` and receives a long-lived per-phone device key. Every later
/// request carries that key under ``deviceKeyAuthField``. No account, relay,
/// or third-party service takes part in either step.
public enum CmxLocalPairing {
    /// URL scheme for local pairing codes. Separate from the account-bound
    /// bundle schemes so a local-only build can register it on its own.
    public static let urlScheme = "cmux-local"
    /// URL host for the pairing action.
    public static let urlHost = "pair"
    /// RPC method that trades a pairing code for a device key. It is the only
    /// method besides `mobile.host.status` a local route serves without a key.
    public static let pairMethod = "mobile.local.pair"
    /// `auth` object field carrying the device key on every other request.
    public static let deviceKeyAuthField = "device_key"
}

public enum CmxLocalPairingPayloadError: Error, Equatable, Sendable {
    case invalidURL
    case unsupportedVersion(Int)
    case missingField(String)
    case invalidPort(Int)
    case expired
}

/// Contents of a local pairing QR code.
///
/// Unlike ``MobileSyncPairingPayload``, this payload carries a secret: the
/// pairing code. It is safe to show because the code expires within minutes,
/// is consumed by the first successful redemption, and only grants a key to a
/// phone that can already reach the Mac's private-network address.
public struct CmxLocalPairingPayload: Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    /// Numeric private-network addresses of the Mac, most preferred first.
    public let hosts: [String]
    public let port: Int
    public let pairingCode: String
    public let macDeviceID: String
    public let macDisplayName: String?
    public let expiresAt: Date

    public init(
        version: Int = Self.currentVersion,
        hosts: [String],
        port: Int,
        pairingCode: String,
        macDeviceID: String,
        macDisplayName: String?,
        expiresAt: Date
    ) {
        self.version = version
        self.hosts = hosts
        self.port = port
        self.pairingCode = pairingCode
        self.macDeviceID = cmxCanonicalDeviceID(macDeviceID)
        self.macDisplayName = macDisplayName
        self.expiresAt = expiresAt
    }

    /// Parses a scanned `cmux-local://pair?...` URL and rejects expired codes.
    public init(url: URL, now: Date = Date()) throws {
        guard url.scheme?.lowercased() == CmxLocalPairing.urlScheme,
              url.host?.lowercased() == CmxLocalPairing.urlHost,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw CmxLocalPairingPayloadError.invalidURL
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        }
        func required(_ name: String) throws -> String {
            guard let found = value(name) else {
                throw CmxLocalPairingPayloadError.missingField(name)
            }
            return found
        }

        let version = Int(try required("v")) ?? 0
        guard version == Self.currentVersion else {
            throw CmxLocalPairingPayloadError.unsupportedVersion(version)
        }
        let hosts = items
            .filter { $0.name == "host" }
            .compactMap { $0.value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        guard !hosts.isEmpty else {
            throw CmxLocalPairingPayloadError.missingField("host")
        }
        let port = Int(try required("port")) ?? 0
        guard (1...65535).contains(port) else {
            throw CmxLocalPairingPayloadError.invalidPort(port)
        }
        guard let expiry = TimeInterval(try required("exp")) else {
            throw CmxLocalPairingPayloadError.missingField("exp")
        }
        let expiresAt = Date(timeIntervalSince1970: expiry)
        guard expiresAt > now else {
            throw CmxLocalPairingPayloadError.expired
        }

        self.init(
            version: version,
            hosts: hosts,
            port: port,
            pairingCode: try required("code"),
            macDeviceID: try required("mac"),
            macDisplayName: value("name"),
            expiresAt: expiresAt
        )
    }

    /// The URL encoded into the QR code.
    public var url: URL {
        var components = URLComponents()
        components.scheme = CmxLocalPairing.urlScheme
        components.host = CmxLocalPairing.urlHost
        var items = [URLQueryItem(name: "v", value: String(version))]
        items += hosts.map { URLQueryItem(name: "host", value: $0) }
        items += [
            URLQueryItem(name: "port", value: String(port)),
            URLQueryItem(name: "code", value: pairingCode),
            URLQueryItem(name: "mac", value: macDeviceID),
            URLQueryItem(name: "exp", value: String(Int(expiresAt.timeIntervalSince1970))),
        ]
        if let macDisplayName {
            items.append(URLQueryItem(name: "name", value: macDisplayName))
        }
        components.queryItems = items
        // Every component is set above, so assembly cannot fail.
        return components.url!
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
