import Foundation
import Testing
@testable import HmuxBrowser

@Suite struct BrowserHistoryLocationTests {
    @Test func foldsDebugAndStagingNamespaces() {
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.hmuxterm.app.debug.my-tag") == "com.hmuxterm.app.debug")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.hmuxterm.app.staging.rc") == "com.hmuxterm.app.staging")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "com.hmuxterm.app") == "com.hmuxterm.app")
    }

    @Test func historyFileURLNestsUnderNamespace() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let location = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.hmuxterm.app.debug.tag")
        #expect(location.namespace == "com.hmuxterm.app.debug")
        #expect(location.historyFileURL.path == "/tmp/appsupport/com.hmuxterm.app.debug/browser_history.json")
    }

    @Test func legacyURLPresentOnlyWhenNamespaceDiffers() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let tagged = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.hmuxterm.app.debug.tag")
        #expect(tagged.legacyTaggedHistoryFileURL?.path == "/tmp/appsupport/com.hmuxterm.app.debug.tag/browser_history.json")

        let prod = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "com.hmuxterm.app")
        #expect(prod.legacyTaggedHistoryFileURL == nil)
    }
}
