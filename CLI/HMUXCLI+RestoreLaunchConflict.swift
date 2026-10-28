import Foundation

extension HMUXCLI {
    /// Both admission and cross-instance lease rejection use the same terminal diagnostic.
    func restoreLaunchConflictError(kind: String, sessionID: String, processID: Int64?) -> CLIError {
        if let processID, processID > 0 {
            let format = String(
                localized: "cli.restore.error.liveOwner",
                defaultValue: "restore: this agent session is already running in process %1$lld. hmux did not start another copy. To take it over here, stop process %1$lld, then run 'hmux restore --surface' again."
            )
            return loggedRestoreError(
                stage: "admission.live-owner",
                detail: "kind=\(kind) session=\(sessionID) pid=\(processID)",
                message: String(format: format, locale: Locale(identifier: "en_US_POSIX"), processID)
            )
        }
        return loggedRestoreError(
            stage: "admission.concurrent-launch",
            detail: "kind=\(kind) session=\(sessionID)",
            message: String(
                localized: "cli.restore.error.launchPending",
                defaultValue: "restore: another launch of this agent session is already starting. Wait for it to appear, or retry 'hmux restore --surface'."
            )
        )
    }
}
