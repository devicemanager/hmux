import AppKit
import Foundation
import Testing

@testable import HmuxFoundation

@Suite struct HmuxAccentColorTests {
    @Test func hmuxModeUsesTheHmuxBlues() {
        let accent = HmuxAccentColor(mode: .hmux)
        #expect(rgbBytes(accent.nsColor(isDark: false)) == [0, 136, 255])
        #expect(rgbBytes(accent.nsColor(isDark: true)) == [0, 145, 255])
    }

    @Test func systemModeUsesTheResolvedControlAccent() throws {
        let accent = HmuxAccentColor(mode: .system)
        for isDark in [false, true] {
            let appearance = try #require(NSAppearance(named: isDark ? .darkAqua : .aqua))
            var expected: [Int] = []
            appearance.performAsCurrentDrawingAppearance {
                expected = rgbBytes(NSColor.controlAccentColor)
            }
            #expect(!expected.isEmpty)
            #expect(rgbBytes(accent.nsColor(isDark: isDark)) == expected)
        }
    }

    @Test func storedModeParsesAndFallsBackToHmux() throws {
        let suite = "HmuxAccentColorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(HmuxAccentColorMode.stored(in: defaults) == .hmux)
        for mode in HmuxAccentColorMode.allCases {
            defaults.set(mode.rawValue, forKey: HmuxAccentColorMode.userDefaultsKey)
            #expect(HmuxAccentColorMode.stored(in: defaults) == mode)
        }
        defaults.set("purple", forKey: HmuxAccentColorMode.userDefaultsKey)
        #expect(HmuxAccentColorMode.stored(in: defaults) == .hmux)
    }

    @Test func customModeDrawsTheStoredColorInBothSchemes() throws {
        let suite = "HmuxAccentColorTests.custom.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(HmuxAccentColorMode.custom.rawValue, forKey: HmuxAccentColorMode.userDefaultsKey)
        defaults.set(" ff6a00 ", forKey: HmuxAccentColorMode.customHexUserDefaultsKey)
        let accent = HmuxAccentColor.stored(in: defaults)
        #expect(accent.mode == .custom)
        #expect(accent.customHex == "#FF6A00")
        #expect(rgbBytes(accent.nsColor(isDark: false)) == [255, 106, 0])
        #expect(rgbBytes(accent.nsColor(isDark: true)) == [255, 106, 0])
    }

    @Test func customModeWithoutAValidColorFallsBackToHmuxBlue() {
        for hex in [nil, "", "not-a-color", "#FF6A00AA"] {
            let accent = HmuxAccentColor(mode: .custom, customHex: hex)
            #expect(accent.customHex == nil)
            #expect(rgbBytes(accent.nsColor(isDark: false)) == [0, 136, 255])
            #expect(rgbBytes(accent.nsColor(isDark: true)) == [0, 145, 255])
        }
    }

    @MainActor
    @Test func observerPostsWhenTheCustomColorChanges() throws {
        let suite = "HmuxAccentColorTests.customObserver.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(HmuxAccentColorMode.custom.rawValue, forKey: HmuxAccentColorMode.userDefaultsKey)
        defaults.set("#FF6A00", forKey: HmuxAccentColorMode.customHexUserDefaultsKey)

        let observer = HmuxAccentColorObserver(defaults: defaults, center: NotificationCenter())
        #expect(observer.current.customHex == "#FF6A00")
        defaults.set("#00FF00", forKey: HmuxAccentColorMode.customHexUserDefaultsKey)
        #expect(observer.refresh() == true)
        #expect(rgbBytes(observer.current.nsColor(isDark: true)) == [0, 255, 0])
        #expect(observer.refresh() == false)
    }

    @Test func settingsFileValueRoundTripsEveryMode() throws {
        #expect(HmuxAccentColorMode.settingsFileValue(mode: .hmux, customHex: "#FF6A00") == "hmux")
        #expect(HmuxAccentColorMode.settingsFileValue(mode: .system, customHex: nil) == "system")
        #expect(HmuxAccentColorMode.settingsFileValue(mode: .custom, customHex: "ff6a00") == "#FF6A00")
        #expect(HmuxAccentColorMode.settingsFileValue(mode: .custom, customHex: nil) == nil)

        for (mode, hex) in [(HmuxAccentColorMode.hmux, nil), (.system, nil), (.custom, "#FF6A00")] as [(HmuxAccentColorMode, String?)] {
            let value = try #require(HmuxAccentColorMode.settingsFileValue(mode: mode, customHex: hex))
            let parsed = try #require(HmuxAccentColorMode.parseSettingsFileValue(value))
            #expect(parsed.mode == mode)
            #expect(parsed.customHex == hex)
        }
        for invalid in ["custom", "purple", "#FF6A", "#FF6A00AA", ""] {
            #expect(HmuxAccentColorMode.parseSettingsFileValue(invalid) == nil)
        }
    }

    @Test func appearanceResolvesToMatchingScheme() throws {
        let dark = try #require(NSAppearance(named: .darkAqua))
        let aqua = try #require(NSAppearance(named: .aqua))
        for accent in HmuxAccentColorMode.allCases.map(HmuxAccentColor.init(mode:)) {
            #expect(rgbBytes(accent.nsColor(for: dark)) == rgbBytes(accent.nsColor(isDark: true)))
            #expect(rgbBytes(accent.nsColor(for: aqua)) == rgbBytes(accent.nsColor(isDark: false)))
            #expect(rgbBytes(accent.nsColor(for: nil)) == rgbBytes(accent.nsColor(isDark: false)))
        }
    }

    @Test func dynamicColorFollowsDrawingAppearance() throws {
        let dark = try #require(NSAppearance(named: .darkAqua))
        let aqua = try #require(NSAppearance(named: .aqua))
        let accent = HmuxAccentColor(mode: .hmux)
        var darkBytes: [Int] = []
        var lightBytes: [Int] = []
        dark.performAsCurrentDrawingAppearance {
            darkBytes = rgbBytes(accent.dynamicNSColor)
        }
        aqua.performAsCurrentDrawingAppearance {
            lightBytes = rgbBytes(accent.dynamicNSColor)
        }
        #expect(darkBytes == [0, 145, 255])
        #expect(lightBytes == [0, 136, 255])
    }

    @Test func builtInAgentStatusBlueResolvesToTheAccent() {
        for accent in HmuxAccentColorMode.allCases.map(HmuxAccentColor.init(mode:)) {
            for hex in ["#4C8DFF", "#4c8dff", " #4C8DFF "] {
                let color = accent.statusEntryColor(hex: hex, isDark: true)
                #expect(color.map(rgbBytes) == rgbBytes(accent.nsColor(isDark: true)))
            }
        }
    }

    @Test func otherStatusColorsStayAsWritten() {
        let accent = HmuxAccentColor(mode: .system)
        #expect(accent.statusEntryColor(hex: "#00FF00", isDark: false).map(rgbBytes) == [0, 255, 0])
        #expect(accent.statusEntryColor(hex: nil, isDark: false) == nil)
        #expect(accent.statusEntryColor(hex: "not-a-color", isDark: false) == nil)
    }

    @MainActor
    @Test func observerResolvesOnceAndPostsOnlyOnChange() throws {
        let suite = "HmuxAccentColorTests.observer.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = NotificationCenter()
        var posts = 0
        let token = center.addObserver(forName: HmuxAccentColor.didChangeNotification, object: nil, queue: nil) { _ in
            posts += 1
        }
        defer { center.removeObserver(token) }

        let observer = HmuxAccentColorObserver(defaults: defaults, center: center)
        #expect(observer.current.mode == .hmux)
        #expect(observer.refresh() == false)

        defaults.set(HmuxAccentColorMode.system.rawValue, forKey: HmuxAccentColorMode.userDefaultsKey)
        #expect(observer.current.mode == .hmux)
        #expect(observer.refresh() == true)
        #expect(observer.current.mode == .system)
        #expect(observer.refresh() == false)

        defaults.set(HmuxAccentColorMode.hmux.rawValue, forKey: HmuxAccentColorMode.userDefaultsKey)
        #expect(observer.refresh() == true)
        #expect(posts == 2)
    }

    private func rgbBytes(_ color: NSColor) -> [Int] {
        guard let srgb = color.usingColorSpace(.sRGB) else { return [] }
        return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent]
            .map { Int(($0 * 255).rounded()) }
    }
}
