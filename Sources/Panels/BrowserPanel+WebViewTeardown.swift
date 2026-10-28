import AppKit
import HmuxBrowser
import WebKit

extension BrowserPanel {
    /// Releases every app-owned attachment before a web view is replaced or closed.
    func tearDownWebViewBeforeReplacement(_ oldWebView: WKWebView, reason: String) {
        guard oldWebView === webView else { return }

        mobileBrowserDialogBroker.resolveAll()

        if let window = oldWebView.window,
           Self.responderChainContains(window.firstResponder, target: oldWebView) {
            window.makeFirstResponder(nil)
        }

        clearBrowserFocusMode(reason: reason)
        invalidateSearchFocusRequests(reason: reason)
        detachWebViewObservers()
        tearDownReactGrabMessageHandler(for: oldWebView, reason: reason)
        tearDownMediaPlaybackMessageHandler(for: oldWebView)
        tearDownPageRestoration(for: oldWebView)
        designModeController.webViewWillBeRemoved(oldWebView)
        webAuthnCoordinator.tearDown(from: oldWebView)
        oldWebView.configuration.userContentController.removeScriptMessageHandler(
            forName: BrowserSSLTrustBypassMessageHandler.name
        )
        sslTrustBypassMessageHandler = nil
        oldWebView.configuration.userContentController.removeScriptMessageHandler(
            forName: MobileBrowserDirtyMessageHandler.name
        )
        mobileBrowserStreamMessageHandler = nil

        BrowserWindowPortalRegistry.detach(webView: oldWebView)
        oldWebView.stopLoading()
        oldWebView.navigationDelegate = nil
        oldWebView.uiDelegate = nil
        oldWebView.hmuxBrowserViewportHostView = nil

        if let oldHmuxWebView = oldWebView as? HmuxWebView {
            oldHmuxWebView.hmuxDownloadDelegate = nil
            oldHmuxWebView.clearBrowserDownloadCallbacks()
            oldHmuxWebView.browserViewportModel = nil
            oldHmuxWebView.onBrowserViewportHierarchyChanged = nil
            oldHmuxWebView.onKeyboardFocusedLinkChanged = nil
            oldHmuxWebView.onMouseBackButton = nil
            oldHmuxWebView.onMouseForwardButton = nil
            oldHmuxWebView.onPhysicalUserInteraction = nil
            oldHmuxWebView.onContextMenuDownloadStateChanged = nil
            oldHmuxWebView.onSessionDownloadEvent = nil
            oldHmuxWebView.onScreenshotCopied = nil
            oldHmuxWebView.onContextMenuOpenLinkInNewTab = nil
            oldHmuxWebView.contextMenuLinkURLProvider = nil
            oldHmuxWebView.contextMenuCanMoveTabToNewWorkspace = nil
            oldHmuxWebView.contextMenuMoveTabToNewWorkspace = nil
            oldHmuxWebView.onSubframeDownloadIntent = nil
        }
        oldWebView.removeFromSuperview()
    }
}
