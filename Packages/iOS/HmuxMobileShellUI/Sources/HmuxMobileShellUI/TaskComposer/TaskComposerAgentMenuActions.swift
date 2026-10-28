#if os(iOS)
import HmuxMobileShellModel

struct TaskComposerAgentMenuActions {
    let selectTemplate: (MobileTaskTemplate.ID) -> Void
    let editTemplates: () -> Void
}
#endif
