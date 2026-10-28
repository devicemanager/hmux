/// Metadata for a registered PostHog runtime flag.
struct HmuxFeatureFlagDefinition: Identifiable, Equatable, Sendable {
    var id: String { key }

    let key: String
    let title: String
    let flagDescription: String
    let defaultWhenUnavailable: Bool
}
