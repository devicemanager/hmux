#if canImport(UIKit)
import Testing
import UIKit
@testable import HmuxMobileTerminal

@MainActor
@Test func terminalArrowNubIsDiscoverable() {
    let nub = TerminalArrowNubView()

    #expect(nub.isAccessibilityElement)
    #expect(nub.accessibilityIdentifier == "terminal.inputAccessory.arrowPad")
    #expect(!(nub.accessibilityLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    #expect(!(nub.accessibilityHint ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
}
#endif
