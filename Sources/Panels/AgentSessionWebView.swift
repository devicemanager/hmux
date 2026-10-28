import AppKit
import HmuxBrowser
import WebKit

@MainActor
final class AgentSessionWebView: HmuxUndoableWebView {
    var onPointerDown: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        PaneFirstClickFocusSettings.isEnabled()
    }

    override func isWebContentUndoRedoCommandEquivalent(_ event: NSEvent) -> Bool {
        event.hmuxIsUndoRedoCommandEquivalent
    }

    override func mouseDown(with event: NSEvent) {
        onPointerDown?()
        super.mouseDown(with: event)
    }
}
