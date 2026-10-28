public import SwiftUI

/// Adds hmux font magnification values to SwiftUI environment lookups.
public extension EnvironmentValues {
    /// The current clamped global font magnification percent.
    ///
    /// hmux scene roots should inject this value with
    /// ``View/hmuxFontMagnificationEnvironment()`` so repeated row labels can
    /// read a pure environment value instead of each subscribing to
    /// `UserDefaults`.
    var hmuxGlobalFontMagnificationPercent: Int {
        get { self[HmuxGlobalFontMagnificationPercentKey.self] }
        set { self[HmuxGlobalFontMagnificationPercentKey.self] = GlobalFontMagnification.clamp(newValue) }
    }
}
