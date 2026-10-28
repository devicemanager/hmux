#if os(iOS)
import HmuxMobileShellModel

/// Stable owner of one provider/Mac model request.
struct TaskComposerModelRefreshID: Hashable {
    let provider: MobileTaskAgentProvider?
    let macPairingID: String
    let connectionIdentity: String?
    let connectionState: MobileConnectionState
}
#endif
