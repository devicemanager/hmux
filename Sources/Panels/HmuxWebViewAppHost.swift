import AppKit
import HmuxBrowser
import WebKit

/// The app's ``HmuxWebViewHost``: forwards each call to the current
/// `AppDelegate.shared` (tests swap it per case), keyboard shortcut settings,
/// and the terminal pasteboard service, which is what `HmuxWebView` called
/// directly before it moved into HmuxBrowser.
@MainActor
final class HmuxWebViewAppHost: HmuxWebViewHost {
    /// Stateless: every call reads `AppDelegate.shared` when it runs, so construction needs no isolation.
    nonisolated init() {}

    func makeDiffViewerNavigationKeyRouter() -> any HmuxWebViewNavigationKeyRouting {
        DiffViewerNavigationKeyRouterAdapter()
    }

    func diffViewerEditableFocusMessageHandler() -> HmuxWebViewScriptMessageHandlerRegistration {
        HmuxWebViewScriptMessageHandlerRegistration(
            handler: DiffViewerEditableFocusMessageHandler.shared,
            name: DiffViewerEditableFocusMessageHandler.name,
            contentWorld: DiffViewerEditableFocusMessageHandler.contentWorld
        )
    }

    func handleBrowserFocusModeKeyEvent(
        _ event: NSEvent,
        webView: HmuxWebView,
        source: String
    ) -> BrowserFocusModeKeyDecision? {
        AppDelegate.shared?.handleBrowserFocusModeKeyEvent(event, webView: webView, source: source)
    }

    func handleBrowserSurfaceKeyEquivalent(_ event: NSEvent) -> Bool? {
        AppDelegate.shared?.handleBrowserSurfaceKeyEquivalent(event)
    }

    func handleBrowserSurfaceKeyEquivalentBeforeMainMenu(_ event: NSEvent) -> Bool? {
        AppDelegate.shared?.handleBrowserSurfaceKeyEquivalentBeforeMainMenu(event)
    }

    func browserFocusModeContextMenuState(for webView: HmuxWebView) -> (isActive: Bool, canToggle: Bool)? {
        AppDelegate.shared?.browserFocusModeContextMenuState(for: webView)
    }

    func toggleBrowserFocusModeFromContextMenu(for webView: HmuxWebView) -> Bool? {
        AppDelegate.shared?.toggleBrowserFocusModeFromContextMenu(for: webView)
    }

    func appendScreenshotContextMenuItems(to menu: NSMenu, for webView: HmuxWebView) {
        webView.appendScreenshotContextMenuItems(to: menu)
    }

    func routesDocumentEditingShortcutToWebContentFirst(
        _ event: NSEvent,
        responder: NSResponder?
    ) -> Bool {
        shouldRouteBrowserDocumentEditingCommandEquivalentThroughWebContentFirst(event, responder: responder)
    }

    func routesFindShortcutToWebContentFirst(
        _ event: NSEvent,
        responder: NSResponder?,
        owningWebView: HmuxWebView?
    ) -> Bool {
        shouldRouteBrowserFindCommandEquivalentThroughWebContentFirst(
            event,
            responder: responder,
            owningWebView: owningWebView
        )
    }

    func routesInlineVSCodeCommandPaletteShortcutToWebContentFirst(
        _ event: NSEvent,
        pageURL: URL?
    ) -> Bool {
        shouldRouteInlineVSCodeCommandPaletteShortcutThroughWebContentFirst(event, pageURL: pageURL)
    }

    func isUndoRedoCommandEquivalent(_ event: NSEvent) -> Bool {
        event.hmuxIsUndoRedoCommandEquivalent
    }

    func hasLiveTabTransfer(in pasteboard: NSPasteboard) -> Bool {
        AppDelegate.shared?.liveTabDragCapabilityResolver.resolve(from: pasteboard) != nil
    }

    func hasLiveSidebarTabDrag(in pasteboard: NSPasteboard) -> Bool {
        SidebarTabDragPayload.hasLiveSession(
            in: pasteboard,
            currentSessionId: AppDelegate.shared?.sidebarWorkspaceDragRegistry.currentSessionId
        )
    }

    func paneFirstClickFocusEnabled() -> Bool {
        PaneFirstClickFocusSettings.isEnabled()
    }

    func replacePasteboardContents(
        of pasteboard: NSPasteboard,
        with items: [NSPasteboardItem],
        expectedChangeCount: Int
    ) async -> HmuxWebViewPasteboardWriteOutcome {
        let result = await GhosttyApp.terminalPasteboard.replaceContentsAndWait(
            of: pasteboard,
            with: items,
            expectedChangeCount: expectedChangeCount
        )
        return HmuxWebViewPasteboardWriteOutcome(
            conditionNotMet: result.status == .conditionNotMet,
            didWrite: result.didWrite
        )
    }

    func typingTimingStart() -> TimeInterval? {
#if DEBUG
        return HmuxTypingTiming.start()
#else
        return nil
#endif
    }

    func typingTimingLogDuration(
        path: String,
        startedAt: TimeInterval?,
        event: NSEvent?,
        extra: String?
    ) {
#if DEBUG
        HmuxTypingTiming.logDuration(path: path, startedAt: startedAt, event: event, extra: extra)
#endif
    }
}

/// Adapts the app's shortcut-settings-driven ``ViewerNavigationKeyRouter`` to
/// the diff viewer router `HmuxWebView` asks its host for.
@MainActor
private final class DiffViewerNavigationKeyRouterAdapter: HmuxWebViewNavigationKeyRouting {
    private let router = ViewerNavigationKeyRouter(actions: [
        .diffViewerScrollDown, .diffViewerScrollUp,
        .diffViewerScrollHalfPageDown, .diffViewerScrollHalfPageUp,
        .diffViewerScrollDownEmacs, .diffViewerScrollUpEmacs,
        .diffViewerScrollToBottom, .diffViewerScrollToTop,
        .diffViewerOpenFileSearch, .diffViewerNextFile, .diffViewerPreviousFile,
        .diffViewerNextHunk, .diffViewerPreviousHunk, .diffViewerToggleViewed,
    ])

    func reset() {
        router.reset()
    }

    func handle(
        _ event: NSEvent,
        perform: (HmuxWebViewNavigationKeyAction) -> Void
    ) -> Bool {
        router.handle(event, isAllowed: { action, event in
            AppDelegate.shared?.shortcutWhenClauseAllows(action: action, event: event) ?? true
        }, perform: { action in
            perform(HmuxWebViewNavigationKeyAction(
                rawValue: action.rawValue,
                opensFileSearch: action == .diffViewerOpenFileSearch
            ))
        })
    }
}
