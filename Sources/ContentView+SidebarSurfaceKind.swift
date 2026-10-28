import HmuxExtensionKit

extension VerticalTabsSidebar {
    func hmuxSidebarSurfaceKind(for panelType: PanelType) -> HmuxSidebarSurfaceKind {
        switch panelType {
        case .terminal:
            return .terminal
        case .browser:
            return .browser
        case .markdown:
            return .markdown
        case .filePreview:
            return .filePreview
        case .rightSidebarTool:
            return .rightSidebarTool
        case .customSidebar, .simulator, .extensionBrowser, .workspaceTodo, .coderouterGuide, .notifications, .cloudVMLoading,
             .mobilePairing, .accountSignIn, .cloudVPNSetup, .chief:
            return .unknown
        case .agentSession:
            return .agentSession
        case .project:
            return .project
        }
    }
}
