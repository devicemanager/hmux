#if DEBUG && os(iOS)
import HmuxMobileShellModel

struct NotificationWorkspaceRoute: Identifiable, Hashable {
    let id: MobileWorkspacePreview.ID
}
#endif
