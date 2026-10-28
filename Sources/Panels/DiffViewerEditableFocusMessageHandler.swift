import WebKit
import HmuxBrowser

@MainActor
final class DiffViewerEditableFocusMessageHandler: NSObject, WKScriptMessageHandler {
    static let name = "hmuxDiffViewerEditableFocus"
    static let contentWorld = WKContentWorld.world(name: "hmuxDiffViewerNavigation")
    static let shared = DiffViewerEditableFocusMessageHandler()

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard DiffCommentsBridge.isTrustedDiffViewerFrame(message.frameInfo),
              let webView = message.webView as? HmuxWebView,
              let body = message.body as? [String: Any],
              let viewer = body["viewer"] as? Bool,
              let editable = body["editable"] as? Bool,
              let rendererReady = body["rendererReady"] as? Bool else { return }
        webView.diffViewerFocusStateDidChange(
            viewer: viewer,
            editable: editable,
            rendererReady: rendererReady
        )
    }
}
