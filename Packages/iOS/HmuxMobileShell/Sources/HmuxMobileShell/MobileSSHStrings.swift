internal import HmuxMobileSupport
import Foundation

/// Localized strings the SSH runtime writes into terminals and statuses.
struct L10nSSH {
    var sessionEnded: String {
        L10n.string("mobile.ssh.session.ended", defaultValue: "Session ended. Type to start a new one.")
    }
    var authFailed: String {
        L10n.string("mobile.ssh.error.authFailed", defaultValue: "The server did not accept this key.")
    }
    var hostKeyRejected: String {
        L10n.string("mobile.ssh.error.hostKeyRejected", defaultValue: "Connection cancelled: server identity not trusted.")
    }
    var connectionRefused: String {
        L10n.string(
            "mobile.ssh.error.connectionRefused",
            defaultValue: "This computer refused the connection. Check the port and that SSH is turned on."
        )
    }
    var connectTimedOut: String {
        L10n.string("mobile.ssh.error.connectTimedOut", defaultValue: "This computer didn't respond. Check the address and your network.")
    }
    var hostNotFound: String {
        L10n.string("mobile.ssh.error.hostNotFound", defaultValue: "No computer was found at this address.")
    }
    var unreachable: String {
        L10n.string("mobile.ssh.error.unreachable", defaultValue: "Couldn't reach this computer. Check the address and your network.")
    }
    var noKey: String {
        L10n.string("mobile.ssh.error.noKey", defaultValue: "Choose a key for this computer first.")
    }
    var tmuxMissing: String {
        L10n.string("mobile.ssh.error.tmuxMissing", defaultValue: "tmux is not installed on this computer.")
    }
    var installingHmuxTUI: String {
        L10n.string("mobile.ssh.hmuxtui.installing", defaultValue: "Installing hmux-tui on this computer…")
    }
    var browserUntitled: String {
        L10n.string("mobile.ssh.browser.untitled", defaultValue: "Browser")
    }
    var browserFailed: String {
        L10n.string("mobile.ssh.browser.failed", defaultValue: "Browser unavailable")
    }
    func hmuxTUIUnsupported(os: String, arch: String) -> String {
        L10n.string(
            "mobile.ssh.error.hmuxTUIUnsupported",
            defaultValue: "hmux-tui doesn't run on this computer (\(os) \(arch))."
        )
    }
    /// The server refused a terminal's `pty-req` or `shell` request.
    var terminalRefused: String {
        L10n.string("mobile.ssh.error.terminalRefused", defaultValue: "This computer refused to open a terminal. Try again.")
    }
    /// The server refused any other channel request; `detail` is its reason.
    func requestRefused(detail: String) -> String {
        L10n.string("mobile.ssh.error.requestRefused", defaultValue: "This computer refused the request (\(detail)).")
    }
    var hmuxTUIMissing: String {
        L10n.string("mobile.ssh.error.hmuxTUIMissing", defaultValue: "hmux-tui is not installed on this computer.")
    }
    var hmuxTUISessionGone: String {
        L10n.string("mobile.ssh.error.hmuxTUISessionGone", defaultValue: "This hmux-tui session is no longer running.")
    }

    /// The row subtitle naming a workspace's kind (PRD D31).
    func kindLabel(_ kind: MobileSSHWorkspaceKind, hmuxTUISession: String? = nil) -> String {
        switch kind {
        case .tmux:
            return L10n.string("mobile.ssh.kind.tmux", defaultValue: "tmux session")
        case .shell:
            return L10n.string("mobile.ssh.kind.shell", defaultValue: "Shell")
        case .hmuxTUI:
            // Workspaces from another hmux-tui session (a laptop's) name it,
            // so same-named workspaces from two sessions stay apart.
            if let session = hmuxTUISession, session != MobileSSHHmuxTUIProvider.sessionName {
                return L10n.string("mobile.ssh.kind.hmuxTUI.session", defaultValue: "hmux-tui · \(session)")
            }
            return L10n.string("mobile.ssh.kind.hmuxTUI", defaultValue: "hmux-tui")
        }
    }
}
