import HmuxCloud
import HmuxSettings
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
struct CloudNightlyOverrideTests {
    private let cloud = HmuxFeatureFlags.cloudMachinesFlag
    private let nightly = HmuxFeatureFlagOverrideCapability(
        bundleIdentifier: "com.hmuxterm.app.nightly", isDebugBuild: false
    )

    @Test(arguments: [
        ("com.hmuxterm.app.nightly", false, true),
        ("com.hmuxterm.app.debug", true, true),
        ("com.hmuxterm.app.debug.issue12705", true, true),
        ("com.hmuxterm.app", false, false),
        ("com.hmuxterm.app", true, false),
        ("com.hmuxterm.app.staging", false, false),
        ("com.hmuxterm.app.debug.issue12705", false, false),
        ("com.hmuxterm.app.nightly-lookalike", false, false),
        ("com.hmuxterm.app.nightly.suffix", false, false),
        ("unknown.NIGHTLY", false, false),
        ("", true, false)
    ])
    func capabilityUsesBuildIdentity(bundleID: String, isDebug: Bool, allowed: Bool) {
        let capability = HmuxFeatureFlagOverrideCapability(
            bundleIdentifier: bundleID, isDebugBuild: isDebug
        )
        #expect(capability.allowsCloudOverride == allowed)
        #expect(capability.policy(for: cloud) == (allowed ? .localFirst : .disabled))
        #expect(capability.policy(for: HmuxFeatureFlags.simulatorFlag) == .remoteFirst)
    }

    @Test
    func taggedArtifactPreservesActivationButClearsDogfoodOverride() throws {
        let suite = "hmux.cloud.debug.marker.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: BetaFeaturesCatalogSection().cloudMachines.userDefaultsKey)
        defaults.set(true, forKey: "hmux.flags.override.\(cloud.key)")

        _ = HmuxFeatureFlags(
            defaults: defaults,
            overrideCapability: HmuxFeatureFlagOverrideCapability(
                bundleIdentifier: "com.hmuxterm.app.debug.old", isDebugBuild: true,
                cloudDogfoodRequested: false, cloudDogfoodMarkerPresent: true
            ),
            remoteFlagValueProvider: { _ in false }
        )

        #expect(defaults.bool(forKey: BetaFeaturesCatalogSection().cloudMachines.userDefaultsKey))
        #expect(defaults.bool(forKey: "hmux.flags.override.\(cloud.key)") == false)
    }

    @Test
    func ordinaryDebugBuildKeepsPersistedCloudSettings() throws {
        let suite = "hmux.cloud.debug.stable.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let betaKey = BetaFeaturesCatalogSection().cloudMachines.userDefaultsKey
        let overrideKey = "hmux.flags.override.\(cloud.key)"
        defaults.set(true, forKey: betaKey)
        defaults.set(true, forKey: overrideKey)

        _ = HmuxFeatureFlags(
            defaults: defaults,
            overrideCapability: HmuxFeatureFlagOverrideCapability(
                bundleIdentifier: "com.hmuxterm.app.debug", isDebugBuild: true, cloudDogfoodRequested: false
            ),
            remoteFlagValueProvider: { _ in false }
        )

        #expect(defaults.bool(forKey: betaKey))
        #expect(defaults.bool(forKey: overrideKey))
    }

    @Test
    func nightlyPickerControlsLegacyLocalOverride() throws {
        let suite = "hmux.cloud.nightly.picker.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let flags = HmuxFeatureFlags(
            defaults: defaults, overrideCapability: nightly, remoteFlagValueProvider: { _ in nil }
        )
        flags.applyLoadedFlags()
        let initial = InternalFlagRowSnapshot(definition: cloud, flags: flags)
        #expect(initial.resolution.allowsLocalOverride)
        #expect(initial.resolution.source == .default)
        #expect(initial.overrideChoice == .noOverride)
        #expect(initial.overrideNote == String(
            localized: "featureFlags.override.cloudDogfoodNote",
            defaultValue: "Cloud overrides take priority in this Nightly or debug build."
        ))

        for choice in [InternalFlagOverrideChoice.on, .off] {
            flags.setOverride(choice.overrideValue, for: cloud)
            let row = InternalFlagRowSnapshot(definition: cloud, flags: flags)
            #expect(row.overrideChoice == choice)
            #expect(row.resolution.effectiveValue == choice.overrideValue)
            #expect(row.resolution.source == .override)
            #expect(row.sourceTitle == String(localized: "featureFlags.source.override", defaultValue: "Override"))
            #expect(row.resolution.allowsLocalOverride)
            #expect(flags.remoteValue(for: cloud) == nil)
            flags.applyLoadedFlags()
            #expect(flags.resolution(for: cloud) == row.resolution)
        }

        flags.setOverride(InternalFlagOverrideChoice.noOverride.overrideValue, for: cloud)
        let cleared = InternalFlagRowSnapshot(definition: cloud, flags: flags)
        #expect(cleared.overrideChoice == .noOverride)
        #expect(cleared.resolution.source == .default)
        #expect(cleared.resolution.effectiveValue == HmuxFeatureFlags.cloudMachinesDefault)
        #expect(cleared.resolution.allowsLocalOverride)
    }

    @Test
    func nightlyOverridesAndClearingPersistAcrossReconstruction() throws {
        let suite = "hmux.cloud.nightly.persistence.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let flags = HmuxFeatureFlags(
            defaults: defaults, overrideCapability: nightly, remoteFlagValueProvider: { _ in false }
        )
        flags.applyLoadedFlags()
        flags.setOverride(true, for: cloud)

        let nextDefaults = try #require(UserDefaults(suiteName: suite))
        let relaunched = HmuxFeatureFlags(
            defaults: nextDefaults, overrideCapability: nightly, remoteFlagValueProvider: { _ in nil }
        )
        #expect(relaunched.remoteValue(for: cloud) == nil)
        #expect(relaunched.overrideValue(for: cloud) == true)
        #expect(relaunched.isCloudMachinesEnabled)
        relaunched.applyLoadedFlags()
        #expect(relaunched.isCloudMachinesEnabled)
        relaunched.setOverride(nil, for: cloud)

        let cleared = HmuxFeatureFlags(defaults: nextDefaults, overrideCapability: nightly)
        #expect(cleared.overrideValue(for: cloud) == nil)
        #expect(cleared.isCloudMachinesEnabled)
        cleared.setOverride(true, for: cloud)
        cleared.clearAllOverrides()
        #expect(cleared.overrideValue(for: cloud) == nil)
        #expect(cleared.isCloudMachinesEnabled)
        let afterClearAll = HmuxFeatureFlags(defaults: nextDefaults, overrideCapability: nightly)
        #expect(afterClearAll.overrideValue(for: cloud) == nil)
        #expect(afterClearAll.isCloudMachinesEnabled)
    }

    @Test
    func stableIgnoresPersistedOverrideAndRejectsWrites() throws {
        // A stable identity disables overrides and keeps the local definition's
        // fallback. The retired key is never loaded from a remote payload.
        let expectedValue = HmuxFeatureFlags.cloudMachinesDefault
        let persistedOverride = !expectedValue
        let suite = "hmux.cloud.stable.override.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let dogfood = HmuxFeatureFlags(defaults: defaults, overrideCapability: nightly)
        dogfood.setOverride(persistedOverride, for: cloud)
        let stable = HmuxFeatureFlags(
            defaults: defaults,
            overrideCapability: .init(bundleIdentifier: "com.hmuxterm.app", isDebugBuild: false),
            remoteFlagValueProvider: { _ in true }
        )
        stable.applyLoadedFlags()
        let row = InternalFlagRowSnapshot(definition: cloud, flags: stable)
        #expect(!row.resolution.allowsLocalOverride)
        #expect(row.resolution.effectiveValue == expectedValue)
        #expect(row.resolution.source == .default)
        #expect(row.overrideNote == String(
            localized: "featureFlags.override.remoteControlledNote",
            defaultValue: "Controlled remotely; local override inactive."
        ))
        stable.setOverride(!persistedOverride, for: cloud)
        #expect(stable.overrideValue(for: cloud) == persistedOverride)
        stable.clearAllOverrides()
        stable.setOverride(true, for: cloud)
        #expect(stable.overrideValue(for: cloud) == nil)
        #expect(stable.isCloudMachinesEnabled == expectedValue)
    }

    @Test
    func nightlyExceptionDoesNotOverrideOtherFlags() throws {
        let suite = "hmux.cloud.nightly.scope.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let flags = HmuxFeatureFlags(
            defaults: defaults, overrideCapability: nightly, remoteFlagValueProvider: { _ in false }
        )
        flags.applyLoadedFlags()
        for flag in HmuxFeatureFlags.allFlags where flag.key != cloud.key {
            flags.setOverride(true, for: flag)
            #expect(flags.overrideValue(for: flag) == nil)
            #expect(!flags.effectiveValue(for: flag))
            #expect(!flags.resolution(for: flag).allowsLocalOverride)
        }
    }

    @Test(arguments: ["com.hmuxterm.app", "com.hmuxterm.app.staging",
                      "com.hmuxterm.app.nightly", "com.hmuxterm.app.debug",
                      "com.hmuxterm.app.debug.cloud-dogfood"])
    func reloadMarkerPreservesTaggedDebugActivation(bundleID: String) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let contents = root.appendingPathComponent("Fixture.bundle/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleVersion": "1",
            "HMUXCloudDogfoodEnabled": true
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: contents.deletingLastPathComponent()))
        let suite = "hmux.cloud.reload.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let betaKey = BetaFeaturesCatalogSection().cloudMachines.userDefaultsKey
        defaults.set(false, forKey: betaKey)
        let flags = HmuxFeatureFlags(
            defaults: defaults,
            overrideCapability: .init(bundle: bundle),
            remoteFlagValueProvider: { _ in false }
        )
        flags.applyLoadedFlags()
        #if DEBUG
        let expected = bundleID == "com.hmuxterm.app.debug.cloud-dogfood"
        #else
        let expected = false
        #endif
        #expect(defaults.bool(forKey: betaKey) == expected)
        #expect(flags.isCloudMachinesEnabled)
        let managedOff = ManagedDevicePolicy(defaults: defaults, releaseDomainDefaults: nil, forcedObject: { _, _ in true })
        #expect(!CloudMachinesFeature.isEnabled(defaults: defaults, policy: managedOff))
    }

}
