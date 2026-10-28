import HmuxCore
import HmuxFoundation
import Darwin

/// Darwin reader for the current process's fixed host and effective user scope.
struct HmuxTopProcessReader: HmuxTopProcessReading {
    func enumerate() -> DarwinProcessListing { DarwinProcessEnumerator().capture() }
    func taskInfo(for pid: Int) -> proc_taskinfo? { HmuxTopProcessSnapshot.taskInfo(for: pid) }
    func resourceUsage(for pid: Int) -> rusage_info_v4? { HmuxTopProcessSnapshot.resourceUsage(for: pid) }
    func processName(pid: Int, fallback: String) -> String {
        HmuxTopProcessSnapshot.processName(pid: pid, fallback: fallback)
    }
    func processPath(pid: Int) -> String? { HmuxTopProcessSnapshot.processPath(pid: pid) }
    func scope(for pid: Int, key: HmuxTopProcessScopeCacheKey) -> HmuxTopProcessScope? {
        // No cross-census scope cache: exec can change argv/environment without
        // changing the PID's birth timestamp. In particular, absence cannot be
        // cached across authoritative restore scans.
        guard case .resolved(let value) = HmuxTopProcessSnapshot.hmuxScopeProbe(
            for: pid, expectedCacheKey: key
        ) else { return nil }
        return value
    }
    func matches(pid: Int, key: HmuxTopProcessScopeCacheKey) -> Bool {
        HmuxTopProcessSnapshot.processMatchesKey(pid, key)
    }
    func processHasExited(pid: Int) -> Bool {
        guard pid > 0, pid <= Int(Int32.max) else { return false }
        return PIDPresence.current(pid: pid_t(pid)) == .absent
    }
}
