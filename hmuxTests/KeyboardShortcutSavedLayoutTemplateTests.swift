import XCTest
import HmuxSettings
@testable import HmuxSettingsUI

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

private typealias ShortcutStroke = HmuxSettings.ShortcutStroke

final class KeyboardShortcutSavedLayoutTemplateTests: XCTestCase {
    func testSaveLayoutTemplateSettingsPackageActionStaysAligned() {
        guard let settingsAction = ShortcutAction(
            rawValue: KeyboardShortcutSettings.Action.saveLayoutTemplate.rawValue
        ) else {
            XCTFail("Expected HmuxSettings.ShortcutAction for saveLayoutTemplate")
            return
        }
        XCTAssertEqual(settingsAction.defaultStroke, ShortcutStroke(key: "s", command: true, control: true))
        XCTAssertEqual(settingsAction.displayName, KeyboardShortcutSettings.Action.saveLayoutTemplate.label)
    }
}
