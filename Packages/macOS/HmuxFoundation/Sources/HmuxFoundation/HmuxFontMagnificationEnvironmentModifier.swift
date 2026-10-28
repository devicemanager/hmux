public import SwiftUI

/// Injects the stored hmux font magnification percent into a SwiftUI subtree.
struct HmuxFontMagnificationEnvironmentModifier: ViewModifier {
    @AppStorage(GlobalFontMagnification.percentKey) private var percent = GlobalFontMagnification.defaultPercent

    func body(content: Content) -> some View {
        content.environment(\.hmuxGlobalFontMagnificationPercent, percent)
    }
}
