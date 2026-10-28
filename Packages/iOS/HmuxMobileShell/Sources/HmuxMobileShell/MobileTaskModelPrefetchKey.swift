internal import HmuxMobileShellModel

struct MobileTaskModelPrefetchKey: Hashable {
    let pairingID: String
    let connectionIdentity: String?
    let provider: MobileTaskAgentProvider
}
