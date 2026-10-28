internal import HmuxMobileShellModel

struct MobileTaskModelPrefetchCatalogPendingWaiter {
    let provider: MobileTaskAgentProvider
    let continuation: CheckedContinuation<MobileTaskModelListResult?, Never>
}
