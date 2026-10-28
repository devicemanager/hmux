import HmuxFoundation
import Foundation
import Testing
@testable import HmuxSettings

struct AccentColorSettingTests {
    @Test func catalogKeyStoresTheModeTheResolverReads() throws {
        let suite = "AccentColorSettingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = AppCatalogSection().accentColor

        #expect(key.id == "app.accentColor")
        #expect(key.userDefaultsKey == HmuxAccentColorMode.userDefaultsKey)
        #expect(key.defaultValue == .hmux)

        let client = UserDefaultsSettingsClient(defaults: defaults)
        for mode in HmuxAccentColorMode.allCases {
            client.set(mode, for: key)
            #expect(HmuxAccentColorMode.stored(in: defaults) == mode)
            #expect(client.value(for: key) == mode)
        }
    }
}
