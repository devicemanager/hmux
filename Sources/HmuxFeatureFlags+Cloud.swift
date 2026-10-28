import Foundation

extension HmuxFeatureFlags {
    // Legacy compatibility definition for tagged debug tooling and migration
    // of persisted overrides. It is intentionally excluded from `allFlags`,
    // so production Cloud availability never reads or delivers this key.
    nonisolated static let cloudMachinesFlag = HmuxFeatureFlagDefinition(
        key: "cloud-machines-enabled-release",
        title: String(localized: "featureFlags.cloudMachines.title", defaultValue: "Cloud Machines"),
        flagDescription: String(
            localized: "featureFlags.cloudMachines.description",
            defaultValue: "Enables the macOS Cloud Machines integration, including entry points, attachments, and background sync."
        ),
        defaultWhenUnavailable: HmuxFeatureFlags.cloudMachinesDefault
    )

    var isCloudMachinesEnabled: Bool { effectiveValue(for: Self.cloudMachinesFlag) }
}
