struct HmuxFeatureFlagResolution: Equatable, Sendable {
    let effectiveValue: Bool
    let source: HmuxFeatureFlagSource
    let allowsLocalOverride: Bool

    init(
        remoteValue: Bool?,
        overrideValue: Bool?,
        defaultValue: Bool,
        overridePolicy: HmuxFeatureFlagOverridePolicy = .remoteFirst
    ) {
        allowsLocalOverride = overridePolicy == .localFirst
            || (overridePolicy == .remoteFirst && remoteValue == nil)
        if allowsLocalOverride, let overrideValue {
            effectiveValue = overrideValue
            source = .override
        } else if let remoteValue {
            effectiveValue = remoteValue
            source = .remote
        } else {
            effectiveValue = defaultValue
            source = .default
        }
    }
}
