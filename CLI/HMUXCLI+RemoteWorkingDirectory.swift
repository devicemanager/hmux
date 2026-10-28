import Foundation

extension HMUXCLI {
    static func applyingSSHPTYAttachBootstrapSubstitutions(
        to command: String,
        workspaceID: String
    ) -> String {
        let remoteInitialCWDB64 = ProcessInfo.processInfo.environment["HMUX_REMOTE_INITIAL_CWD"]
            .flatMap { $0.isEmpty ? nil : Data($0.utf8).base64EncodedString() } ?? ""
        return command
            .replacingOccurrences(of: "__HMUX_WORKSPACE_ID__", with: workspaceID)
            .replacingOccurrences(of: "__HMUX_SURFACE_ID__", with: ProcessInfo.processInfo.environment["HMUX_SURFACE_ID"] ?? "")
            .replacingOccurrences(of: "__HMUX_TERMINAL_LIFECYCLE_ID__", with: ProcessInfo.processInfo.environment["HMUX_TERMINAL_LIFECYCLE_ID"] ?? "")
            .replacingOccurrences(of: "__HMUX_SSH_ATTEMPT_ID__", with: ProcessInfo.processInfo.environment["HMUX_SSH_ATTEMPT_ID"] ?? "")
            .replacingOccurrences(of: "__HMUX_REMOTE_INITIAL_CWD_B64__", with: remoteInitialCWDB64)
    }
}
