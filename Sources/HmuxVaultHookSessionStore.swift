import Foundation

/// A hmux-owned hook-session store that a built-in Vault agent may read.
enum HmuxVaultHookSessionStore: String, Codable, Hashable, Sendable {
    case amp
}
