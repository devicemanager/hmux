public import AppKit
public import Foundation
public import SwiftUI

/// The one accent for hmux-drawn chrome: the color that means "this is the
/// active or attention-worthy thing" (selected workspace, attention ring,
/// pane swap source, canvas focus, scroll markers, agent status).
///
/// A value carries the resolved `app.accentColor` mode. ``HmuxAccentColorObserver``
/// resolves it once per change and hands it to the sidebar snapshot, the
/// SwiftUI environment (``SwiftUI/EnvironmentValues/hmuxAccentColor``) and
/// AppKit chrome, so drawing code never reads settings itself. Native
/// controls (toggles, pickers, text cursors, list selection) always keep the
/// system accent. User overrides such as the sidebar selection color or the
/// pane flash color are applied by their callers and win over both modes.
public struct HmuxAccentColor: Sendable, Hashable {
    /// Posted on the default center, with the ``HmuxAccentColorObserver`` as
    /// the object, when the resolved accent changes.
    public static let didChangeNotification = Notification.Name("hmux.accentColorDidChange")

    /// Hex the built-in agent hooks write for Running and Needs input. The
    /// sidebar draws entries carrying it with the accent instead.
    public static let builtInAgentStatusHex = "#4C8DFF"

    public let mode: HmuxAccentColorMode

    /// Normalized `#RRGGBB` color drawn in ``HmuxAccentColorMode/custom``
    /// mode. `nil` there falls back to hmux blue.
    public let customHex: String?

    public init(mode: HmuxAccentColorMode = .defaultValue) {
        self.init(mode: mode, customHex: nil)
    }

    public init(mode: HmuxAccentColorMode, customHex: String?) {
        self.mode = mode
        self.customHex = HmuxAccentColorMode.normalizedCustomHex(customHex)
    }

    /// The accent stored in `defaults` (`app.accentColor`).
    public static func stored(in defaults: UserDefaults = .standard) -> HmuxAccentColor {
        HmuxAccentColor(
            mode: .stored(in: defaults),
            customHex: HmuxAccentColorMode.storedCustomHex(in: defaults)
        )
    }

    /// hmux's own blue for a light or dark appearance.
    public static func hmuxBlue(isDark: Bool) -> NSColor {
        NSColor(
            srgbRed: 0,
            green: (isDark ? 145.0 : 136.0) / 255.0,
            blue: 1.0,
            alpha: 1.0
        )
    }

    /// The accent for a light or dark appearance.
    public func nsColor(isDark: Bool) -> NSColor {
        switch mode {
        case .hmux:
            return Self.hmuxBlue(isDark: isDark)
        case .system:
            return Self.systemAccent(isDark: isDark)
        case .custom:
            return customHex.flatMap { NSColor(hex: $0) } ?? Self.hmuxBlue(isDark: isDark)
        }
    }

    /// The accent for an AppKit appearance. `nil` resolves as light.
    public func nsColor(for appearance: NSAppearance?) -> NSColor {
        nsColor(isDark: appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    }

    /// Appearance-aware accent that resolves against the drawing appearance,
    /// like a system dynamic color.
    public var dynamicNSColor: NSColor {
        let accent = self
        return NSColor(name: "hmuxAccent") { appearance in
            accent.nsColor(for: appearance)
        }
    }

    /// SwiftUI accent that follows the view's color scheme.
    public var color: Color {
        Color(nsColor: dynamicNSColor)
    }

    /// Color for a sidebar status entry's hex. The built-in agent status blue
    /// resolves to the accent; any other valid hex is used as written.
    public func statusEntryColor(hex: String?, isDark: Bool) -> NSColor? {
        guard let hex else { return nil }
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.caseInsensitiveCompare(Self.builtInAgentStatusHex) == .orderedSame {
            return nsColor(isDark: isDark)
        }
        return NSColor(hex: trimmed)
    }

    /// Identifies what the accent draws: the mode plus both scheme colors,
    /// so a `system` value changes when the macOS accent does.
    public var fingerprint: String {
        "\(mode.rawValue):\(nsColor(isDark: false).hexString()):\(nsColor(isDark: true).hexString())"
    }

    /// Two values are equal when they draw the same colors.
    public static func == (lhs: HmuxAccentColor, rhs: HmuxAccentColor) -> Bool {
        lhs.fingerprint == rhs.fingerprint
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fingerprint)
    }

    /// `controlAccentColor` resolved to a concrete sRGB color for the scheme,
    /// so layer colors and hex conversions see the current system accent.
    private static func systemAccent(isDark: Bool) -> NSColor {
        let accent = NSColor.controlAccentColor
        guard let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua) else {
            return accent.usingColorSpace(.sRGB) ?? accent
        }
        var resolved = accent
        appearance.performAsCurrentDrawingAppearance {
            resolved = accent.usingColorSpace(.sRGB) ?? accent
        }
        return resolved
    }
}

private struct HmuxAccentColorEnvironmentKey: EnvironmentKey {
    static let defaultValue = HmuxAccentColor()
}

extension EnvironmentValues {
    /// The resolved hmux accent. Window roots inject the observer's value.
    public var hmuxAccentColor: HmuxAccentColor {
        get { self[HmuxAccentColorEnvironmentKey.self] }
        set { self[HmuxAccentColorEnvironmentKey.self] = newValue }
    }
}
