#if os(iOS)
import HmuxMobileShellModel

struct TaskComposerAgentMenuValue: Equatable {
    let templates: [MobileTaskTemplate]
    let selectedTemplateID: MobileTaskTemplate.ID?
    let isDisabled: Bool
}
#endif
