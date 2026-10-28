import Foundation
import Testing
@testable import HmuxSettings

private func makeLanguageScratchDefaults() -> (String, UserDefaults) {
    let suiteName = "hmux.tests.\(UUID().uuidString)"
    return (suiteName, UserDefaults(suiteName: suiteName)!)
}

private func makeLanguageSettingsStore(defaults: UserDefaults, suiteName: String) -> LanguageSettingsStore {
    LanguageSettingsStore(defaults: defaults, domainName: suiteName)
}

@Suite("LanguageSettingsStore override ownership")
struct LanguageSettingsOverrideTests {
    @Test func systemSelectionPreservesForeignAppleLanguagesOverride() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        defaults.set(["zh-Hant"], forKey: "AppleLanguages")
        store.applyLanguageOverride(.system)

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] as? [String] == ["zh-Hant"])
    }

    @Test func systemSelectionPreservesManuallyReplacedOverride() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        store.applyLanguageOverride(.zhHant)
        defaults.set(["fr"], forKey: "AppleLanguages")
        store.applyLanguageOverride(.system)

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] as? [String] == ["fr"])
    }

    @Test func systemSelectionRemovesHmuxOwnedOverride() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        store.applyLanguageOverride(.zhHant)
        store.applyLanguageOverride(.system)

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] == nil)
        #expect(defaults.persistentDomain(forName: suiteName)?["appLanguageAppliedOverride"] == nil)
    }

    @Test func explicitSelectionWritesOverrideAndCompanion() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        store.applyLanguageOverride(.zhHant)

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] as? [String] == ["zh-Hant"])
        #expect(defaults.persistentDomain(forName: suiteName)?["appLanguageAppliedOverride"] as? String == "zh-Hant")
    }

    @Test func reconcileRepairsMissingOverrideForExplicitSelection() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        defaults.set("zh-Hant", forKey: "appLanguage")
        store.reconcileLanguageOverrideAtLaunch()

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] as? [String] == ["zh-Hant"])
    }

    @Test func reconcileRepairsStaleHmuxOwnedOverride() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        defaults.set("zh-Hant", forKey: "appLanguage")
        defaults.set(["en"], forKey: "AppleLanguages")
        defaults.set("en", forKey: "appLanguageAppliedOverride")
        store.reconcileLanguageOverrideAtLaunch()

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] as? [String] == ["zh-Hant"])
        #expect(defaults.persistentDomain(forName: suiteName)?["appLanguageAppliedOverride"] as? String == "zh-Hant")
    }

    @Test func reconcileLeavesForeignOverrideUntouched() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        defaults.set("zh-Hant", forKey: "appLanguage")
        defaults.set(["ja"], forKey: "AppleLanguages")
        store.reconcileLanguageOverrideAtLaunch()

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] as? [String] == ["ja"])
        #expect(defaults.persistentDomain(forName: suiteName)?["appLanguageAppliedOverride"] == nil)
    }

    @Test func reconcileAdoptsPreFixOwnedState() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        defaults.set("zh-Hant", forKey: "appLanguage")
        defaults.set(["zh-Hant"], forKey: "AppleLanguages")
        store.reconcileLanguageOverrideAtLaunch()

        #expect(defaults.persistentDomain(forName: suiteName)?["appLanguageAppliedOverride"] as? String == "zh-Hant")

        store.applyLanguageOverride(.system)
        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] == nil)
    }

    @Test func reconcileRemovesHmuxOwnedOverrideWhenStoredIsSystem() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        defaults.set(["zh-Hant"], forKey: "AppleLanguages")
        defaults.set("zh-Hant", forKey: "appLanguageAppliedOverride")
        store.reconcileLanguageOverrideAtLaunch()

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] == nil)
        #expect(defaults.persistentDomain(forName: suiteName)?["appLanguageAppliedOverride"] == nil)
    }

    @Test func reconcilePreservesForeignOverrideForSystemSelection() {
        let (suiteName, defaults) = makeLanguageScratchDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = makeLanguageSettingsStore(defaults: defaults, suiteName: suiteName)

        defaults.set(["zh-Hant"], forKey: "AppleLanguages")
        store.reconcileLanguageOverrideAtLaunch()

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] as? [String] == ["zh-Hant"])
        #expect(defaults.persistentDomain(forName: suiteName)?["appLanguageAppliedOverride"] == nil)
    }
}
