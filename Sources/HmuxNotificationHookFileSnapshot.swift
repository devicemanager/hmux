import Foundation

/// Couples a hook file's cache identity with the exact bytes represented by that identity.
struct HmuxNotificationHookFileSnapshot {
    let fingerprint: HmuxNotificationHookFileFingerprint
    let contents: Data?
}
