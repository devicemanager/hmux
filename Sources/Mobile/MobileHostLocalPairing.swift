import HMUXMobileCore
import CryptoKit
import Foundation
import Security

/// Account-free pairing for the private-network TCP route.
///
/// The Mac shows a short-lived, single-use pairing code in a QR. A phone that
/// reaches the listener redeems it once for a random per-phone device key and
/// presents that key on every later request. The Mac stores only SHA-256
/// digests of issued keys, so the store file grants nothing if it leaks, and
/// revoking a phone takes effect on its next request.
final class MobileHostLocalPairing: @unchecked Sendable {
    static let shared = MobileHostLocalPairing()

    struct PairedDevice: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let keyDigest: String
        let pairedAt: Date
    }

    struct IssuedCode: Equatable, Sendable {
        let code: String
        let expiresAt: Date
    }

    struct Redemption: Equatable, Sendable {
        let deviceID: String
        let deviceKey: String
    }

    /// Codes outlive a slow QR scan but not an unattended screen.
    static let codeLifetime: TimeInterval = 5 * 60
    /// Wrong guesses allowed before the active code is burned.
    static let maximumFailedRedemptions = 5

    private let lock = NSLock()
    private let storeURL: URL
    private let now: @Sendable () -> Date
    private var activeCode: IssuedCode?
    private var failedRedemptions = 0
    private var devices: [PairedDevice]

    init(
        storeURL: URL = MobileHostLocalPairing.defaultStoreURL(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storeURL = storeURL
        self.now = now
        devices = Self.load(from: storeURL)
    }

    /// Issues a fresh code, replacing any code still outstanding.
    func issueCode() -> IssuedCode {
        let issued = IssuedCode(
            code: Self.randomToken(byteCount: 16),
            expiresAt: now().addingTimeInterval(Self.codeLifetime)
        )
        lock.lock()
        activeCode = issued
        failedRedemptions = 0
        lock.unlock()
        return issued
    }

    /// Trades a valid code for a new device key. The code is consumed on
    /// success and burned after too many wrong guesses.
    func redeem(code: String, deviceName: String?) -> Redemption? {
        lock.lock()
        defer { lock.unlock() }
        guard let active = activeCode, active.expiresAt > now() else {
            activeCode = nil
            return nil
        }
        guard Self.constantTimeEquals(code, active.code) else {
            failedRedemptions += 1
            if failedRedemptions >= Self.maximumFailedRedemptions {
                activeCode = nil
            }
            return nil
        }
        activeCode = nil
        let key = Self.randomToken(byteCount: 32)
        let trimmedName = deviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let device = PairedDevice(
            id: UUID().uuidString,
            name: (trimmedName?.isEmpty == false ? trimmedName : nil) ?? "iPhone",
            keyDigest: Self.digest(key),
            pairedAt: now()
        )
        devices.append(device)
        persistLocked()
        return Redemption(deviceID: device.id, deviceKey: key)
    }

    /// The paired device a key belongs to, or nil for unknown or revoked keys.
    func device(forKey key: String?) -> PairedDevice? {
        guard let key, !key.isEmpty else { return nil }
        let candidate = Self.digest(key)
        lock.lock()
        defer { lock.unlock() }
        // Compare against every entry so timing does not reveal list position.
        var match: PairedDevice?
        for device in devices where Self.constantTimeEquals(candidate, device.keyDigest) {
            match = device
        }
        return match
    }

    func pairedDevices() -> [PairedDevice] {
        lock.lock()
        defer { lock.unlock() }
        return devices
    }

    @discardableResult
    func revoke(deviceID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let before = devices.count
        devices.removeAll { $0.id == deviceID }
        guard devices.count != before else { return false }
        persistLocked()
        return true
    }

    // MARK: - Storage

    static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? "com.hmuxterm.app"
        return base
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("mobile-local-devices.json")
    }

    private static func load(from url: URL) -> [PairedDevice] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([PairedDevice].self, from: data)) ?? []
    }

    private func persistLocked() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(devices) else { return }
        let directory = storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard (try? data.write(to: storeURL, options: [.atomic])) != nil else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storeURL.path)
    }

    // MARK: - Crypto helpers

    static func randomToken(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func digest(_ key: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices {
            difference |= a[index] ^ b[index]
        }
        return difference == 0
    }
}
