import HmuxFoundation
import Foundation

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
final class DeferredAdmissionTestOwner: DeferredAgentResumeAdmissionOwner {
    var deferredAgentResumeRestoresByPanelId: [UUID: DeferredAgentResumeRestore] = [:]
    var deferredAgentResumeIndexTask: Task<Void, Never>?
    let scans = AsyncStream<Set<UUID>>.makeStream()
    let waits = AsyncStream<Void>.makeStream()
    private let deinitialization: AsyncStream<Void>.Continuation?

    init(deinitialization: AsyncStream<Void>.Continuation? = nil) {
        self.deinitialization = deinitialization
    }

    deinit { deinitialization?.yield() }

    var deferredAgentResumeIndexProvider: @MainActor @Sendable (UInt64) async -> SharedLiveAgentIndexRefreshOutcome {
        { _ in .index(.empty) }
    }

    var deferredAgentResumeEvidenceWait: @Sendable ([AgentPIDProcessIdentity]) async -> Void {
        let entered = waits.continuation
        return { _ in
            let (events, continuation) = AsyncStream<Void>.makeStream()
            defer { continuation.finish() }
            entered.yield()
            for await _ in events {}
        }
    }

    func resolveDeferredAgentResumeRestores(using index: RestorableAgentSessionIndex) {
        scans.continuation.yield(Set(deferredAgentResumeRestoresByPanelId.keys))
    }

    func presentPendingAgentResumeRestores() {}
}
