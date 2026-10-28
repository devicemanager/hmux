import HmuxCore
import Foundation
import Darwin

// Result of probing a single process for its hmux scope. `resolved` means the
// probe completed (the scope may legitimately be absent) within this census.
// `unavailable` means a transient failure (process exited mid-probe, pid reuse,
// or a failed sysctl); later censuses retry rather than retaining an absent scope.
enum HmuxTopProcessScopeProbeResult: Equatable {
    case resolved(HmuxTopProcessScope?)
    case unavailable
}

extension HmuxTopProcessSnapshot {
    static func scopeCacheKey(from kinfo: kinfo_proc) -> HmuxTopProcessScopeCacheKey {
        let startTime = kinfo.kp_proc.p_un.__p_starttime
        return HmuxTopProcessScopeCacheKey(
            pid: Int(kinfo.kp_proc.p_pid),
            startSeconds: Int(startTime.tv_sec),
            startMicroseconds: Int(startTime.tv_usec)
        )
    }

    static func scopeCacheKey(from bsdInfo: proc_bsdinfo) -> HmuxTopProcessScopeCacheKey {
        HmuxTopProcessScopeCacheKey(
            pid: Int(bsdInfo.pbi_pid),
            startSeconds: Int(bsdInfo.pbi_start_tvsec),
            startMicroseconds: Int(bsdInfo.pbi_start_tvusec)
        )
    }

    // Scope belongs to this census only. A failed args read with a still-matching
    // identity is a readable listing with unavailable scope (e.g. another user).
    // An exit/reuse race is unavailable, and the next fresh census retries it.
    // The post-read identity check prevents argv from a reused PID being attached
    // to the older topology record.
    static func hmuxScopeProbe(
        for pid: Int,
        expectedCacheKey: HmuxTopProcessScopeCacheKey
    ) -> HmuxTopProcessScopeProbeResult {
        guard pid > 0, pid <= Int(Int32.max) else { return .unavailable }

        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, Int32(pid)]
        var size: size_t = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else {
            // Sizing failed: permanent denial if still alive, else exit race.
            return processMatchesKey(pid, expectedCacheKey) ? .resolved(nil) : .unavailable
        }

        var buffer = [UInt8](repeating: 0, count: size)
        let success = buffer.withUnsafeMutableBytes { rawBuffer in
            sysctl(&mib, u_int(mib.count), rawBuffer.baseAddress, &size, nil, 0) == 0
        }
        guard success else {
            return processMatchesKey(pid, expectedCacheKey) ? .resolved(nil) : .unavailable
        }
        guard processMatchesKey(pid, expectedCacheKey) else {
            return .unavailable
        }

        return .resolved(hmuxScope(fromKernProcArgs: Array(buffer.prefix(Int(size)))))
    }

    // True when `pid` is still the same process (same start time) as the key.
    static func processMatchesKey(
        _ pid: Int,
        _ expectedCacheKey: HmuxTopProcessScopeCacheKey
    ) -> Bool {
        guard let process = kinfoProc(for: pid) else { return false }
        return scopeCacheKey(from: process) == expectedCacheKey
    }

    static func hmuxScope(fromKernProcArgs bytes: [UInt8]) -> HmuxTopProcessScope? {
        guard let process = processArgumentsAndEnvironment(fromKernProcArgs: bytes) else {
            return nil
        }
        return hmuxScope(arguments: process.arguments, environment: process.environment)
    }

    static func hmuxScope(arguments: [String], environment: [String: String]) -> HmuxTopProcessScope? {
        if let environmentScope = hmuxScopeFromEnvironment(environment) {
            return environmentScope
        }
        if let hookScope = hmuxHookMonitorScope(arguments: arguments) {
            return hookScope
        }
        return nil
    }

    private static func hmuxScopeFromEnvironment(_ environment: [String: String]) -> HmuxTopProcessScope? {
        let workspaceID = uuidValue(in: environment, keys: ["HMUX_WORKSPACE_ID", "HMUX_TAB_ID"])
        let surfaceID = uuidValue(in: environment, keys: ["HMUX_SURFACE_ID", "HMUX_PANEL_ID"])
        guard workspaceID != nil || surfaceID != nil else { return nil }
        return HmuxTopProcessScope(
            workspaceID: workspaceID,
            surfaceID: surfaceID,
            attributionReason: "hmux-environment"
        )
    }

    private static func hmuxHookMonitorScope(arguments: [String]) -> HmuxTopProcessScope? {
        guard containsSubcommandPath(["hooks", "codex", "monitor"], in: arguments) else {
            return nil
        }
        let workspaceID = uuidOptionValue(in: arguments, names: ["--workspace"])
        let surfaceID = uuidOptionValue(in: arguments, names: ["--surface", "--panel"])
        guard workspaceID != nil || surfaceID != nil else { return nil }
        return HmuxTopProcessScope(
            workspaceID: workspaceID,
            surfaceID: surfaceID,
            attributionReason: "hmux-hook-arguments"
        )
    }

    private static func containsSubcommandPath(_ path: [String], in arguments: [String]) -> Bool {
        let normalizedPath = path.map { $0.lowercased() }
        guard !normalizedPath.isEmpty, arguments.count >= normalizedPath.count + 1 else { return false }
        let executableName = URL(fileURLWithPath: arguments[0])
            .lastPathComponent
            .lowercased()
        guard executableName == "hmux" else { return false }
        let subcommands = arguments
            .dropFirst()
            .prefix(normalizedPath.count)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return Array(subcommands) == normalizedPath
    }

    private static func uuidValue(in environment: [String: String], keys: [String]) -> UUID? {
        for key in keys {
            guard let raw = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty,
                  let uuid = UUID(uuidString: raw) else {
                continue
            }
            return uuid
        }
        return nil
    }

    private static func uuidOptionValue(in arguments: [String], names: Set<String>) -> UUID? {
        for index in arguments.indices {
            let argument = arguments[index].trimmingCharacters(in: .whitespacesAndNewlines)
            for name in names {
                let prefix = "\(name)="
                guard argument.hasPrefix(prefix) else { continue }
                let raw = String(argument.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty, let uuid = UUID(uuidString: raw) else { continue }
                return uuid
            }

            guard names.contains(argument) else { continue }
            let valueIndex = arguments.index(after: index)
            guard valueIndex < arguments.endIndex else { continue }
            let raw = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty, let uuid = UUID(uuidString: raw) else { continue }
            return uuid
        }
        return nil
    }

    private static func kinfoProc(for pid: Int) -> kinfo_proc? {
        guard pid > 0, pid <= Int(Int32.max) else { return nil }

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        var process = kinfo_proc()
        var length = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, u_int(mib.count), &process, &length, nil, 0)
        guard result == 0,
              length >= MemoryLayout<kinfo_proc>.stride,
              process.kp_proc.p_pid == pid_t(pid) else {
            return nil
        }
        return process
    }
}

extension HmuxTopProcessArguments {
    func matchesHMUXScope(workspaceId: UUID, surfaceId: UUID) -> Bool {
        guard let scope = HmuxTopProcessSnapshot.hmuxScope(arguments: arguments, environment: environment) else {
            return false
        }
        return scope.workspaceID == workspaceId && scope.surfaceID == surfaceId
    }
}
