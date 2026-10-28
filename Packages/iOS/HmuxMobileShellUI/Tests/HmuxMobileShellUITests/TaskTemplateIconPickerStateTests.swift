#if os(iOS)
import Testing
@testable import HmuxMobileShellUI

@MainActor
@Suite struct TaskTemplateIconPickerStateTests {
    @Test func customEmojiInputReflectsCurrentSelection() {
        #expect(TaskTemplateIconPicker.customEmojiInput(for: "🚀") == "🚀")
        #expect(TaskTemplateIconPicker.customEmojiInput(for: "terminal").isEmpty)
        #expect(TaskTemplateIconPicker.customEmojiInput(for: "agent:codex").isEmpty)
    }
}
#endif
