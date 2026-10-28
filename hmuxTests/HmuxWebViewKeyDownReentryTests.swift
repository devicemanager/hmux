import AppKit
import HmuxBrowser
import Carbon.HIToolbox
import Testing
import WebKit
import ObjectiveC.runtime

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

private var hmuxUnitTestHmuxWebViewKeyDownOriginalIMP: IMP?
private var hmuxUnitTestHmuxWebViewKeyDownHook: ((HmuxWebView, NSEvent) -> Bool)?

private final class FakeWKInspectorUndoResponderView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

private final class BrowserReturnContentResponder: NSView {
    private(set) var receivedKeyCodes: [UInt16] = []

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        receivedKeyCodes.append(event.keyCode)
    }
}

private final class BrowserUndoMenuActionSpy: NSObject {
    private(set) var invoked = false

    @objc func didInvoke(_ sender: Any?) {
        _ = sender
        invoked = true
    }
}

/// Hooks `HmuxWebView.keyDown(with:)` for the duration of one test window.
///
/// WHY scoped, not process-wide: other suites in the same app host (for
/// example `HmuxWebViewWebContentUndoTests`) swizzle the same key path on
/// `WKWebView` and exercise `HmuxWebView.keyDown` with no hook set. A
/// permanent swizzle left behind by this suite made those tests recurse until
/// the stack overflowed whenever the two suites shared a process. The hook
/// calls the captured original implementation directly and is removed again
/// in `uninstallHmuxUnitTestHmuxWebViewKeyDownOverride()`.
private func installHmuxUnitTestHmuxWebViewKeyDownOverride() {
    guard hmuxUnitTestHmuxWebViewKeyDownOriginalIMP == nil else { return }

    let selector = #selector(HmuxWebView.keyDown(with:))
    guard let method = class_getInstanceMethod(HmuxWebView.self, selector) else {
        fatalError("Unable to locate HmuxWebView keyDown method for swizzling")
    }

    typealias KeyDownIMP = @convention(c) (AnyObject, Selector, NSEvent) -> Void
    let originalIMP = method_getImplementation(method)
    let original = unsafeBitCast(originalIMP, to: KeyDownIMP.self)
    let hooked: @convention(block) (HmuxWebView, NSEvent) -> Void = { webView, event in
        if hmuxUnitTestHmuxWebViewKeyDownHook?(webView, event) == true {
            return
        }
        original(webView, selector, event)
    }
    hmuxUnitTestHmuxWebViewKeyDownOriginalIMP = originalIMP
    method_setImplementation(method, imp_implementationWithBlock(hooked))
}

private func uninstallHmuxUnitTestHmuxWebViewKeyDownOverride() {
    guard let originalIMP = hmuxUnitTestHmuxWebViewKeyDownOriginalIMP,
          let method = class_getInstanceMethod(
              HmuxWebView.self,
              #selector(HmuxWebView.keyDown(with:))
          ) else { return }
    method_setImplementation(method, originalIMP)
    hmuxUnitTestHmuxWebViewKeyDownOriginalIMP = nil
}

@Suite(.serialized)
final class HmuxWebViewKeyDownReentryTests {
    @Test(arguments: [UInt16(36), 76], [NSEvent.ModifierFlags(), .shift, .command])
    @MainActor
    func browserReturnFromContentResponderReachesOwningWebView(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let webView = try #require(window.firstResponder as? HmuxWebView)
            let contentResponder = BrowserReturnContentResponder(frame: webView.bounds)
            webView.addSubview(contentResponder)
            #expect(window.makeFirstResponder(contentResponder))
            let event = try #require(makeKeyDownEvent(
                key: "\r",
                modifiers: modifiers,
                keyCode: keyCode,
                windowNumber: window.windowNumber
            ))

            #expect(window.performKeyEquivalent(with: event))
            #expect(keyDownEvents().map(\.keyCode) == [keyCode])
            #expect(contentResponder.receivedKeyCodes.isEmpty)
            #expect(window.firstResponder === contentResponder)
        }
    }

    @Test
    @MainActor
    func browserReturnDoesNotRouteToPageWhenWebInspectorResponderIsFocused() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let webView = try #require(window.firstResponder as? HmuxWebView)
            let inspectorView = FakeWKInspectorUndoResponderView(
                frame: NSRect(x: 0, y: 0, width: 32, height: 20)
            )
            webView.addSubview(inspectorView)
            #expect(window.makeFirstResponder(inspectorView))

            let event = try #require(makeKeyDownEvent(
                key: "\r",
                modifiers: [],
                keyCode: 36,
                windowNumber: window.windowNumber
            ))

            _ = window.performKeyEquivalent(with: event)

            #expect(keyDownEvents().isEmpty)
            #expect(window.firstResponder === inspectorView)
        }
    }

    @Test
    @MainActor
    func browserReturnConsumesOnlyItsOwnSynchronousReplay() throws {
        try withHookedBrowserKeyDownWindow { window, _ in
            let webView = try #require(window.firstResponder as? HmuxWebView)
            let event = try #require(makeKeyDownEvent(
                key: "\r",
                modifiers: [],
                keyCode: 36,
                windowNumber: window.windowNumber
            ))
            var deliveries = 0
            var replayHandled = false
            hmuxUnitTestHmuxWebViewKeyDownHook = { currentWebView, forwardedEvent in
                guard currentWebView === webView else { return false }
                deliveries += 1
                replayHandled = webView.withBrowserWebKitKeyDownDispatch {
                    window.performKeyEquivalent(with: forwardedEvent)
                }
                return true
            }

            #expect(window.performKeyEquivalent(with: event))
            #expect(deliveries == 1)
            #expect(replayHandled)
        }
    }

    @Test
    @MainActor
    func printableOptionTextRoutesToBrowserKeyDownOnce() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let event = try #require(makeKeyDownEvent(
                key: "å",
                modifiers: [.option],
                keyCode: 0,
                windowNumber: window.windowNumber
            ))

            #expect(window.performKeyEquivalent(with: event))
            #expect(keyDownEvents().map(\.keyCode) == [0])
        }
    }

    @Test
    @MainActor
    func printableOptionTextDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let event = try #require(makeKeyDownEvent(
                key: "å",
                modifiers: [.option],
                keyCode: 0,
                windowNumber: window.windowNumber
            ))

            let webView = try #require(window.firstResponder as? WKWebView)
            let handled = webView.withBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            #expect(!handled)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @Test
    @MainActor
    func browserReturnDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let event = try #require(makeKeyDownEvent(
                key: "\r",
                modifiers: [],
                keyCode: 36,
                windowNumber: window.windowNumber
            ))

            let webView = try #require(window.firstResponder as? WKWebView)
            let handled = webView.withBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            #expect(!handled)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @Test
    @MainActor
    func browserArrowDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            let event = try #require(makeKeyDownEvent(
                key: "\u{F701}",
                modifiers: [],
                keyCode: 125,
                windowNumber: window.windowNumber
            ))

            let webView = try #require(window.firstResponder as? WKWebView)
            let handled = webView.withBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            #expect(!handled)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @Test
    @MainActor
    func browserUndoRedoFallsBackToBrowserKeyDownWhenWebKitDeclines() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            installHmuxUnitTestWKWebViewPerformKeyEquivalentOverride()

            var performKeyEquivalentEvents: [NSEvent] = []
            hmuxUnitTestWKWebViewPerformKeyEquivalentHook = { currentWebView, event in
                guard currentWebView.window === window else { return nil }
                performKeyEquivalentEvents.append(event)
                return false
            }
            defer { hmuxUnitTestWKWebViewPerformKeyEquivalentHook = nil }

            let event = try #require(makeKeyDownEvent(
                key: "z",
                modifiers: [.command],
                keyCode: UInt16(kVK_ANSI_Z),
                windowNumber: window.windowNumber
            ))

            #expect(window.performKeyEquivalent(with: event))
            #expect(performKeyEquivalentEvents.map(\.keyCode) == [UInt16(kVK_ANSI_Z)])
            #expect(keyDownEvents().map(\.keyCode) == [UInt16(kVK_ANSI_Z)])
        }
    }

    @Test
    @MainActor
    func browserUndoRedoDoesNotRouteDuringWebKitKeyDownReentry() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            installHmuxUnitTestWKWebViewPerformKeyEquivalentOverride()

            var performKeyEquivalentEvents: [NSEvent] = []
            hmuxUnitTestWKWebViewPerformKeyEquivalentHook = { currentWebView, event in
                guard currentWebView.window === window else { return nil }
                performKeyEquivalentEvents.append(event)
                return false
            }
            defer { hmuxUnitTestWKWebViewPerformKeyEquivalentHook = nil }

            let event = try #require(makeKeyDownEvent(
                key: "z",
                modifiers: [.command],
                keyCode: UInt16(kVK_ANSI_Z),
                windowNumber: window.windowNumber
            ))

            let webView = try #require(window.firstResponder as? WKWebView)
            let handled = webView.withBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            #expect(handled)
            #expect(performKeyEquivalentEvents.isEmpty)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @Test
    @MainActor
    func browserUndoRedoDoesNotBypassMenuWhenWebInspectorResponderIsFocused() throws {
        try withHookedBrowserKeyDownWindow { window, keyDownEvents in
            installHmuxUnitTestWKWebViewPerformKeyEquivalentOverride()

            let spy = BrowserUndoMenuActionSpy()
            let previousMenu = installUndoMenu(target: spy)
            defer { NSApp.mainMenu = previousMenu }

            let webView = try #require(window.contentView?.subviews.compactMap { $0 as? HmuxWebView }.first)
            let inspectorView = FakeWKInspectorUndoResponderView(frame: NSRect(x: 0, y: 0, width: 32, height: 20))
            webView.addSubview(inspectorView)

            var performKeyEquivalentEvents: [NSEvent] = []
            hmuxUnitTestWKWebViewPerformKeyEquivalentHook = { currentWebView, event in
                guard currentWebView === webView else { return nil }
                performKeyEquivalentEvents.append(event)
                return true
            }
            defer { hmuxUnitTestWKWebViewPerformKeyEquivalentHook = nil }

            #expect(window.makeFirstResponder(inspectorView))
            let event = try #require(makeKeyDownEvent(
                key: "z",
                modifiers: [.command],
                keyCode: UInt16(kVK_ANSI_Z),
                windowNumber: window.windowNumber
            ))

            #expect(window.performKeyEquivalent(with: event))
            #expect(spy.invoked)
            #expect(performKeyEquivalentEvents.isEmpty)
            #expect(keyDownEvents().isEmpty)
        }
    }

    @MainActor
    private func withHookedBrowserKeyDownWindow(
        _ body: (NSWindow, () -> [NSEvent]) throws -> Void
    ) rethrows {
        _ = NSApplication.shared
        AppDelegate.installWindowResponderSwizzlesForTesting()
        installHmuxUnitTestHmuxWebViewKeyDownOverride()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = container

        let webView = HmuxWebView(frame: container.bounds, configuration: WKWebViewConfiguration(), host: HmuxWebViewAppHost())
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)

        var keyDownEvents: [NSEvent] = []
        hmuxUnitTestHmuxWebViewKeyDownHook = { currentWebView, event in
            guard currentWebView === webView else { return false }
            keyDownEvents.append(event)
            return true
        }

        window.makeKeyAndOrderFront(nil)
        defer {
            hmuxUnitTestHmuxWebViewKeyDownHook = nil
            window.orderOut(nil)
            uninstallHmuxUnitTestHmuxWebViewKeyDownOverride()
        }

        #expect(window.makeFirstResponder(webView))
        try body(window, { keyDownEvents })
    }

    private func installUndoMenu(target: NSObject) -> NSMenu? {
        let previousMenu = NSApp.mainMenu
        let mainMenu = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        let undoItem = NSMenuItem(
            title: "Undo",
            action: #selector(BrowserUndoMenuActionSpy.didInvoke(_:)),
            keyEquivalent: "z"
        )
        undoItem.keyEquivalentModifierMask = [.command]
        undoItem.target = target
        editMenu.addItem(undoItem)
        mainMenu.addItem(editItem)
        mainMenu.setSubmenu(editMenu, for: editItem)
        _ = NSApplication.shared
        NSApp.mainMenu = mainMenu
        return previousMenu
    }

    private func makeKeyDownEvent(
        key: String,
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16,
        windowNumber: Int
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: keyCode
        )
    }
}
