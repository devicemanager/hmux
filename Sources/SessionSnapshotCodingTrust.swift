import Foundation

extension CodingUserInfoKey {
    /// Allows app-owned persisted snapshots to decode reserved built-in Vault capabilities.
    static let hmuxTrustedPersistedSessionSnapshot = CodingUserInfoKey(
        rawValue: "com.hmuxterm.session-snapshot.trusted"
    )!
}

extension Decoder {
    var isTrustedHmuxPersistedSessionSnapshot: Bool {
        userInfo[.hmuxTrustedPersistedSessionSnapshot] as? Bool == true
    }
}
