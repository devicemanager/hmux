import Foundation

/// Decodes one command-name aggregate from the memory diagnostic payload.
struct HmuxTaskManagerMemoryGroup: Sendable {
    let id: String
    let name: String
    let rssBytes: Int64
    let processCount: Int
    let processIds: [Int]
    let attribution: HmuxTaskManagerMemoryGroupAttribution

    init?(_ payload: [String: Any]) {
        guard let name = HmuxTaskManagerMemoryDiagnostic.string(payload["name"]) else {
            return nil
        }
        let processCount = HmuxTaskManagerMemoryDiagnostic.int(payload["process_count"]) ?? 0
        guard processCount > 0 else { return nil }
        self.id = HmuxTaskManagerMemoryDiagnostic.string(payload["id"]) ?? name.lowercased()
        self.name = name
        self.rssBytes = HmuxTaskManagerMemoryDiagnostic.int64(payload["rss_bytes"])
        self.processCount = processCount
        self.processIds = HmuxTaskManagerMemoryDiagnostic.intArray(payload["pids"])
        let topAttribution = HmuxTaskManagerMemoryAttribution(payload["top_attribution"] as? [String: Any])
        self.attribution = HmuxTaskManagerMemoryGroupAttribution(
            payload["group_attribution"] as? [String: Any] ?? [:]
        )
            ?? topAttribution.map(HmuxTaskManagerMemoryGroupAttribution.common)
            ?? .unattributed
    }
}
