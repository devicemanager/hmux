import HmuxCloud
import HmuxFoundation
import SwiftUI

struct CloudTreePlaceholderContent: View {
    let placeholder: CloudTreePlaceholder
    let style: CloudTreeStyle

    @Environment(\.hmuxGlobalFontMagnificationPercent) private var magnification

    var body: some View {
        HStack(alignment: .center, spacing: GlobalFontMagnification.scaledSize(style.iconGap, percent: magnification)) {
            Group {
                switch placeholder.style {
                case .connecting:
                    ProgressView().controlSize(.mini)
                case .error:
                    HmuxSystemSymbolImage(
                        systemName: "exclamationmark.triangle",
                        pointSize: max(style.iconSize, 9),
                        weight: .regular,
                        tint: Color(nsColor: .secondaryLabelColor)
                    )
                case .createMachine:
                    HmuxSystemSymbolImage(
                        systemName: "plus",
                        pointSize: max(style.iconSize, 9),
                        weight: .medium,
                        tint: Color(nsColor: .secondaryLabelColor)
                    )
                case .empty:
                    // Keeps the icon column so the text lines up with the
                    // rows it stands in for, like "No other devices yet".
                    Color.clear
                case .dimmed:
                    HmuxSystemSymbolImage(
                        systemName: "moon.zzz",
                        pointSize: max(style.iconSize, 9),
                        weight: .regular,
                        tint: Color(nsColor: .tertiaryLabelColor)
                    )
                }
            }
            .frame(width: max(style.iconSlot, 12))
            Text(placeholder.text)
                .hmuxFont(size: placeholder.style == .empty ? style.detailSize : style.detailSize + 1, design: style.fontDesign)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.trailing, style.rowGrid.trailingPadding)
    }
}
