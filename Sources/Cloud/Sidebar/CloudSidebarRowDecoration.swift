import HmuxCloud
import HmuxFoundation
import SwiftUI

/// An unread badge in the leading identity column, followed by an optional pin.
/// Read rows keep the compact identity edge; unread rows reserve the badge slot.
/// Immutable input keeps AppKit cell reuse independent of observable stores.
struct CloudSidebarRowDecoration: ViewModifier {
    @Environment(\.hmuxAccentColor) private var hmuxAccent
    let isPinned: Bool
    let showsAttentionSlot: Bool
    let hasUnreadNotification: Bool
    var attentionSlot: CGFloat = CloudTreeStyle.compact.rowGrid.attentionSlot
    @Environment(\.hmuxGlobalFontMagnificationPercent) private var magnification

    func body(content: Content) -> some View {
        // Keep read rows flush with the outline's content edge. A row earns the
        // leading slot only while it has unread attention, so the compact tree
        // does not carry an empty gutter between the caret and its identity.
        HStack(spacing: 2) {
            if showsAttentionSlot && hasUnreadNotification {
                Circle()
                    .fill(hmuxAccent.color)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel(String(localized: "cloudTree.organization.unread", defaultValue: "Unread notification"))
                    .help(String(localized: "cloudTree.organization.unread", defaultValue: "Unread notification"))
                    .frame(width: GlobalFontMagnification.scaledSize(attentionSlot, percent: magnification))
                    .allowsHitTesting(false)
            }
            if isPinned {
                HmuxSystemSymbolImage(
                    magnified: "pin.fill",
                    pointSize: 9,
                    weight: .semibold,
                    tint: Color(nsColor: .secondaryLabelColor)
                )
                .fixedSize()
                // Machine rows have no icon after the pin, so the pin keeps
                // its own gap before the name.
                .padding(.trailing, GlobalFontMagnification.scaledSize(3, percent: magnification))
                .accessibilityLabel(String(localized: "taskManager.row.pinned", defaultValue: "Pinned"))
            }
            content
        }
    }
}
