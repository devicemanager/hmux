import XCTest
import HmuxBrowser
import AppKit
import WebKit

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
final class InactivePaneFirstClickFocusTests: XCTestCase {
    private let settingsKey = "paneFirstClickFocus.enabled"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        super.tearDown()
    }

    func testTerminalViewAcceptsFirstMouseWhenSettingEnabled() {
        UserDefaults.standard.set(true, forKey: settingsKey)

        let view = GhosttyNSView(frame: .zero)

        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }

    func testTerminalViewRejectsFirstMouseWhenSettingDisabled() {
        UserDefaults.standard.set(false, forKey: settingsKey)

        let view = GhosttyNSView(frame: .zero)

        XCTAssertFalse(view.acceptsFirstMouse(for: nil))
    }

    func testBrowserViewAcceptsFirstMouseWhenSettingEnabled() {
        UserDefaults.standard.set(true, forKey: settingsKey)

        let view = HmuxWebView(frame: .zero, configuration: WKWebViewConfiguration(), host: HmuxWebViewAppHost())

        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }

    func testBrowserViewRejectsFirstMouseWhenSettingDisabled() {
        UserDefaults.standard.set(false, forKey: settingsKey)

        let view = HmuxWebView(frame: .zero, configuration: WKWebViewConfiguration(), host: HmuxWebViewAppHost())

        XCTAssertFalse(view.acceptsFirstMouse(for: nil))
    }

    func testMarkdownWebViewAcceptsFirstMouseWhenSettingEnabled() {
        UserDefaults.standard.set(true, forKey: settingsKey)

        let view = MarkdownWebView(frame: .zero, configuration: WKWebViewConfiguration())

        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }

    func testMarkdownWebViewRejectsFirstMouseWhenSettingDisabled() {
        UserDefaults.standard.set(false, forKey: settingsKey)

        let view = MarkdownWebView(frame: .zero, configuration: WKWebViewConfiguration())

        XCTAssertFalse(view.acceptsFirstMouse(for: nil))
    }
}
