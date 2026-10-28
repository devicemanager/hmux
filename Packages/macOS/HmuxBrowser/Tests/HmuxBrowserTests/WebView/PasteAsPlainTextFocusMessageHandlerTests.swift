import Foundation
import Testing

@testable import HmuxBrowser

@Suite("Browser paste focus message boundary")
struct PasteAsPlainTextFocusMessageHandlerTests {
    /// The parser rejects values that cannot safely drive the paste state.
    @Test("accepts only a boolean canPaste payload")
    func parsesPayloadConservatively() {
        #expect(HmuxWebView.pasteAsPlainTextTargetAvailable(from: ["canPaste": true]) == true)
        #expect(HmuxWebView.pasteAsPlainTextTargetAvailable(from: ["canPaste": false]) == false)
        #expect(HmuxWebView.pasteAsPlainTextTargetAvailable(from: ["canPaste": "true"]) == nil)
        #expect(HmuxWebView.pasteAsPlainTextTargetAvailable(from: ["other": true]) == nil)
        #expect(HmuxWebView.pasteAsPlainTextTargetAvailable(from: NSNull()) == nil)
    }

    /// The callback boundary delivers valid payloads through MainActor.
    @Test("schedules valid payload updates on MainActor")
    func schedulesPayloadUpdate() async {
        let delivered = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            HmuxWebView.schedulePasteAsPlainTextTargetUpdate(from: ["canPaste": true]) { canPaste in
                continuation.resume(returning: canPaste)
            }
        }

        #expect(delivered)
    }
}
