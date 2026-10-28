/// Identifies notification-hook resolution for one working directory and global configuration.
struct HmuxNotificationHookCacheKey: Hashable {
    let directory: String?
    let globalConfigPath: String
}
