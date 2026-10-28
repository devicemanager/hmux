#if canImport(UIKit)
import HMUXMobileCore
import HmuxMobileTerminal
import Foundation

extension GhosttySurfaceRepresentable.Coordinator {
    func scheduleTheme(_ theme: TerminalTheme, generation: UInt64) {
        themeApplicationScheduler.schedule(generation: generation) { [weak surfaceView] in
            surfaceView?.applyTerminalConfigTheme(theme)
        }
    }
}

extension GhosttySurfaceView {
    func seedThemeParityPreviewIfRequested() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["HMUX_UITEST_THEME_PARITY_PREVIEW"] == "1" else {
            return
        }
        processOutput(Data("hmux theme parity renderer\r\nvisible terminal content\r\n".utf8))
        #endif
    }
}
#endif
