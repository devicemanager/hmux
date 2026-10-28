import SwiftUI
import HmuxUpdater
import HmuxFoundation

/// The replacement check is waiting for Sparkle's previous session to finish.
struct PreparingUpdateCheckView: View {
    let checking: UpdateState.Checking
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(String(
                    localized: "update.preparingCheck",
                    defaultValue: "Preparing Update Check…"
                ))
                .hmuxFont(size: 13)
            }

            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                    checking.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.small)
            }
        }
        .padding(16)
    }
}
