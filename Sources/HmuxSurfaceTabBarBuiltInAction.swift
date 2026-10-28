import Bonsplit
import Foundation

enum HmuxSurfaceTabBarBuiltInAction: String, Codable, Sendable, CaseIterable, Hashable {
    case newWorkspace = "hmux.newWorkspace"
    case newAgentChat = "hmux.newAgentChat"
    case cloudVM = "hmux.cloudvm"
    case newCloudWorkspace = "hmux.newCloudWorkspace"
    case newCloudMachine = "hmux.newCloudMachine"
    case mobileConnect = "hmux.mobileconnect"
    case newTerminal = "hmux.newTerminal"
    case newBrowser = "hmux.newBrowser"
    case newSimulator = "hmux.newSimulator"
    case splitRight = "hmux.splitRight"
    case splitDown = "hmux.splitDown"
    case copyWorkingDirectory = "hmux.copyWorkingDirectory"
    case copyProjectRoot = "hmux.copyProjectRoot"
    case copyScreen = "hmux.copyScreen"

    init?(configID: String) {
        switch configID {
        case "hmux.newWorkspace", "newWorkspace":
            self = .newWorkspace
        case "hmux.newAgentChat", "hmux.agentChat", "newAgentChat", "new-agent-chat", "agentChat":
            self = .newAgentChat
        case "hmux.cloudvm", "hmux.cloudVM", "cloudVM", "cloudvm",
             "hmux.newCloudVM", "hmux.newCloudVm", "newCloudVM", "newCloudVm",
             "hmux.startCloudVM", "hmux.startCloudVm", "startCloudVM", "startCloudVm":
            self = .cloudVM
        case "hmux.newCloudWorkspace", "newCloudWorkspace":
            self = .newCloudWorkspace
        case "hmux.newCloudMachine", "newCloudMachine":
            self = .newCloudMachine
        case "hmux.mobileconnect", "hmux.mobileConnect", "mobileConnect", "mobileconnect",
             "hmux.connectPhone", "connectPhone":
            self = .mobileConnect
        case "hmux.newTerminal", "newTerminal":
            self = .newTerminal
        case "hmux.newBrowser", "newBrowser":
            self = .newBrowser
        case "hmux.newSimulator", "newSimulator", "new-simulator", "simulator":
            self = .newSimulator
        case "hmux.splitRight", "splitRight":
            self = .splitRight
        case "hmux.splitDown", "splitDown":
            self = .splitDown
        case "hmux.copyWorkingDirectory", "copyWorkingDirectory":
            self = .copyWorkingDirectory
        case "hmux.copyProjectRoot", "copyProjectRoot":
            self = .copyProjectRoot
        case "hmux.copyScreen", "copyScreen":
            self = .copyScreen
        default:
            return nil
        }
    }

    var configID: String {
        rawValue
    }

    var resolvedConfigMetadata: (title: String, keywords: [String]) {
        switch self {
        case .newWorkspace:
            return (String(localized: "command.newWorkspace.title", defaultValue: "New Workspace"), ["create", "new", "workspace"])
        case .newAgentChat:
            return (String(localized: "command.newAgentChat.title", defaultValue: "New agent chat"), ["create", "new", "agent", "chat", "browser", "codex", "claude"])
        case .cloudVM:
            return (String(localized: "command.cloudVM.title", defaultValue: "Open Base"), ["base", "cloud", "vm", "virtual", "machine", "remote"])
        case .newCloudWorkspace:
            return (String(localized: "command.newCloudWorkspace.title", defaultValue: "New Cloud Workspace"), ["new", "create", "cloud", "vm", "machine", "workspace", "remote"])
        case .newCloudMachine:
            return (String(localized: "command.newCloudMachine.title", defaultValue: "New Cloud Machine"), ["new", "create", "cloud", "vm", "machine", "workspace", "remote"])
        case .mobileConnect:
            return (
                String(localized: "command.mobileConnect.title", defaultValue: "Open Mobile Pairing"),
                ["tailscale", "iroh", "iphone", "ipad", "mobile", "phone", "pair", "connect", "qr"]
            )
        case .newTerminal:
            return (String(localized: "command.newTerminalTab.title", defaultValue: "New Terminal Tab"), ["new", "terminal", "tab", "surface"])
        case .newBrowser:
            return (String(localized: "command.newBrowserTab.title", defaultValue: "New Browser Tab"), ["new", "browser", "tab", "surface"])
        case .newSimulator:
            return (String(localized: "command.newSimulatorPane.title", defaultValue: "New Simulator Pane"), ["new", "simulator", "iphone", "ipad", "ios", "surface"])
        case .splitRight:
            return (String(localized: "command.terminalSplitRight.title", defaultValue: "Split Right"), ["terminal", "split", "right"])
        case .splitDown:
            return (String(localized: "command.terminalSplitDown.title", defaultValue: "Split Down"), ["terminal", "split", "down"])
        case .copyWorkingDirectory:
            return (String(localized: "command.copyWorkingDirectory.title", defaultValue: "Copy Working Directory"), ["copy", "clipboard", "path", "directory", "cwd", "pwd"])
        case .copyProjectRoot:
            return (String(localized: "command.copyProjectRoot.title", defaultValue: "Copy Project Root"), ["copy", "clipboard", "project", "git", "root", "repository", "path"])
        case .copyScreen:
            return (String(localized: "command.copyScreen.title", defaultValue: "Copy Visible Screen"), ["copy", "clipboard", "screen", "output", "terminal", "visible"])
        }
    }

    var defaultIcon: String {
        switch self {
        case .newWorkspace:
            return "plus.square"
        case .newAgentChat:
            return "message"
        case .cloudVM:
            return "cloud"
        case .newCloudWorkspace:
            return "cloud.fill"
        case .newCloudMachine:
            return "cloud"
        case .mobileConnect:
            return "iphone"
        case .newTerminal:
            return "terminal"
        case .newBrowser:
            return "globe"
        case .newSimulator:
            return "iphone.gen3"
        case .splitRight:
            return "square.split.2x1"
        case .splitDown:
            return "square.split.1x2"
        case .copyWorkingDirectory:
            return "doc.on.doc"
        case .copyProjectRoot:
            return "arrow.triangle.branch"
        case .copyScreen:
            return "text.viewfinder"
        }
    }

    var bonsplitAction: BonsplitConfiguration.SplitActionButton.Action? {
        switch self {
        case .newWorkspace, .newAgentChat, .cloudVM, .newCloudWorkspace, .newCloudMachine, .mobileConnect, .newSimulator,
             .copyWorkingDirectory, .copyProjectRoot, .copyScreen:
            return nil
        case .newTerminal:
            return .newTerminal
        case .newBrowser:
            return .newBrowser
        case .splitRight:
            return .splitRight
        case .splitDown:
            return .splitDown
        }
    }
}

extension HmuxSurfaceTabBarBuiltInAction {
    /// The user-editable shortcut that triggers the same behavior as this
    /// built-in action. Menus that list built-in actions read the live
    /// `KeyboardShortcutSettings` value through this mapping, so a rebind or
    /// an unbind in Settings or `hmux.json` shows up the next time the menu
    /// opens. Actions with no hmux-owned shortcut return nil.
    var shortcutAction: KeyboardShortcutSettings.Action? {
        switch self {
        case .newWorkspace: return .newTab
        case .newCloudWorkspace: return .newCloudWorkspace
        case .newCloudMachine: return .newCloudMachine
        case .newTerminal: return .newSurface
        case .newBrowser: return .openBrowser
        case .splitRight: return .splitRight
        case .splitDown: return .splitDown
        case .newAgentChat, .cloudVM, .mobileConnect, .newSimulator,
             .copyWorkingDirectory, .copyProjectRoot, .copyScreen: return nil
        }
    }

}
