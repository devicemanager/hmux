import Foundation

enum AppBundleIconPersistencePolicy {
    private static let stableReleaseBundleIdentifier = "com.hmuxterm.app"
    private static let stableReleaseAppBundleName = "hmux.app"
    static let disablePersistenceArgument = "--hmux-disable-bundle-icon-persistence"
    static let disablePersistenceDefaultsKey = "hmuxDisableBundleIconPersistence"

    static func updateDisableDefault(defaults: UserDefaults, launchArguments: [String]) {
        defaults.set(
            launchArguments.contains(disablePersistenceArgument),
            forKey: disablePersistenceDefaultsKey
        )
    }

    static func shouldPersist(
        bundleIdentifier: String?,
        appBundleLastPathComponent: String?,
        persistenceDisabled: Bool = false
    ) -> Bool {
        guard !persistenceDisabled else {
            return false
        }

        // Channel variants own their identity through build-time bundle metadata.
        // Persisted Finder icons would override that metadata and can leak into
        // packaged artifacts after CI smoke launches the app bundle.
        return bundleIdentifier == stableReleaseBundleIdentifier
            && appBundleLastPathComponent == stableReleaseAppBundleName
    }
}
