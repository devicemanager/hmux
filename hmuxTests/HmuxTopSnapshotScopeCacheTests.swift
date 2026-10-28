import Testing
import Foundation
import Darwin
#if canImport(hmux_DEV)
@testable import hmux_DEV
#else
@testable import hmux
#endif

/// Native probe contract; cross-census scope caching is covered by the shared
/// snapshot tests, including same-PID exec and bounded diagnostic reuse.
struct HmuxTopSnapshotScopeCacheTests {
    @Test func liveProcessScopeProbeResolves() throws {
        let pid = Int(Darwin.getpid())
        var info = proc_bsdinfo()
        let expectedSize = MemoryLayout<proc_bsdinfo>.stride
        let size = proc_pidinfo(pid_t(pid), PROC_PIDTBSDINFO, 0, &info, Int32(expectedSize))
        try #require(size == expectedSize)
        let cacheKey = HmuxTopProcessSnapshot.scopeCacheKey(from: info)

        let result = HmuxTopProcessSnapshot.hmuxScopeProbe(for: pid, expectedCacheKey: cacheKey)

        switch result {
        case .resolved:
            break
        case .unavailable:
            Issue.record("live process probe should resolve, even when it has no hmux scope")
        }
    }

}
