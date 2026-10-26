import Foundation
import Security

/// A device key a Mac issued to this phone through ``CmxLocalPairing``.
public struct CmxLocalDeviceCredential: Codable, Equatable, Sendable {
    /// The secret the phone sends as `auth.device_key`.
    public let deviceKey: String
    /// The Mac's id for this phone, used when revoking it there.
    public let deviceID: String
    public let macDeviceID: String
    public let macDisplayName: String?

    public init(deviceKey: String, deviceID: String, macDeviceID: String, macDisplayName: String?) {
        self.deviceKey = deviceKey
        self.deviceID = deviceID
        self.macDeviceID = cmxCanonicalDeviceID(macDeviceID)
        self.macDisplayName = macDisplayName
    }
}

/// Reads and writes device keys by exact Tailscale endpoint.
public protocol CmxLocalDeviceKeyStoring: AnyObject, Sendable {
    func save(_ credential: CmxLocalDeviceCredential, hosts: [String], port: Int) throws
    func credential(host: String, port: Int) -> CmxLocalDeviceCredential?
}

/// Keychain storage for local device keys, addressed by the exact Tailscale
/// endpoint they were issued for.
///
/// Keys are bound to the endpoint rather than the Mac id because the first
/// dial after pairing only knows the address; a key is sent only to the
/// numeric Tailscale address and port it was issued through.
public final class CmxLocalDeviceKeyStore: CmxLocalDeviceKeyStoring, @unchecked Sendable {
    private let service: String
    private let accessGroup: String?
    private let lock = NSLock()

    public init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    /// Store for the running app, private to its bundle.
    public static func current(accessGroup: String? = nil, bundle: Bundle = .main) -> CmxLocalDeviceKeyStore {
        CmxLocalDeviceKeyStore(
            service: "\(bundle.bundleIdentifier ?? "cmux").local-device-keys",
            accessGroup: accessGroup
        )
    }

    /// Saves `credential` for every listed host on `port`. Hosts that are not
    /// numeric Tailscale addresses are skipped.
    public func save(_ credential: CmxLocalDeviceCredential, hosts: [String], port: Int) throws {
        let data = try JSONEncoder().encode(credential)
        lock.lock()
        defer { lock.unlock() }
        for host in hosts {
            guard let account = Self.account(host: host, port: port) else { continue }
            var query = baseQuery(account: account)
            SecItemDelete(query as CFDictionary)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
        }
    }

    /// The credential issued for this exact endpoint, if any.
    public func credential(host: String, port: Int) -> CmxLocalDeviceCredential? {
        guard let account = Self.account(host: host, port: port) else { return nil }
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        lock.lock()
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        lock.unlock()
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(CmxLocalDeviceCredential.self, from: data)
    }

    /// Removes every stored endpoint key.
    public func removeAll() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        lock.lock()
        SecItemDelete(query as CFDictionary)
        lock.unlock()
    }

    static func account(host: String, port: Int) -> String? {
        guard (1...65535).contains(port),
              let address = CmxTailscalePeerAddress(host) else { return nil }
        return "\(address.value)|\(port)"
    }

    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
