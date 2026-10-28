/// Stores resolved hooks and their content-sensitive fingerprints for one cache key.
struct HmuxNotificationHookCacheEntry {
    let fingerprints: [HmuxNotificationHookFileFingerprint]
    let hooks: [HmuxResolvedNotificationHook]
    var lastAccessSequence: UInt64
}
