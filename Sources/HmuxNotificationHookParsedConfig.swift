/// Associates a parsed notification-hook configuration with its content fingerprint.
struct HmuxNotificationHookParsedConfig {
    let fingerprint: HmuxNotificationHookFileFingerprint
    let config: HmuxConfigFile?
}
