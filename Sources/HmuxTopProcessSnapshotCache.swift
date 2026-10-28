import HmuxFoundation
import Foundation

extension HmuxTopProcessSnapshot {
    /// Builds the app-scoped process census authority at the composition root.
    static func makeProcessSnapshotService() -> ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields> {
        ProcessSnapshotService(
            capture: { try HmuxTopProcessSampler().capture() },
            enrich: { try HmuxTopProcessSampler().enrich($0, fields: $1) }
        )
    }

    /// Enumerates after this request. An older diagnostic census cannot authorize
    /// lifecycle decisions merely because its enrichment finished more recently.
    static func capture(
        includeProcessDetails: Bool = false,
        includeHMUXScope: Bool = true,
        includeResources: Bool = true,
        service: ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields>? = nil
    ) async -> HmuxTopProcessSnapshot {
        await capture(
            fields: HmuxTopProcessFields(details: includeProcessDetails, scope: includeHMUXScope, resources: includeResources),
            freshness: .afterRequest, service: service ?? defaultProcessSnapshotService()
        )
    }

    /// Permits diagnostic reuse only within the explicit age bound from census start.
    static func captureCached(
        includeProcessDetails: Bool = false,
        includeHMUXScope: Bool = true,
        includeResources: Bool = true,
        maximumAge: TimeInterval,
        service: ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields>? = nil
    ) async -> HmuxTopProcessSnapshot {
        await capture(
            fields: HmuxTopProcessFields(details: includeProcessDetails, scope: includeHMUXScope, resources: includeResources),
            freshness: .maximumAge(.seconds(max(0, maximumAge))), service: service ?? defaultProcessSnapshotService()
        )
    }

    private static func capture(
        fields: HmuxTopProcessFields, freshness: ProcessSnapshotFreshness,
        service: ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields>
    ) async -> HmuxTopProcessSnapshot {
        do {
            return try await service.snapshot(fields: fields, freshness: freshness).snapshot
        } catch {
            // Expiry, cancellation and admission failure are unavailable evidence,
            // never a complete empty machine. Safety callers must fail closed.
            return HmuxTopProcessSnapshot(
                processes: [], sampledAt: Date(), includesProcessDetails: fields.contains(.details),
                includesHMUXScope: fields.contains(.scope), includesResources: fields.contains(.resources),
                enumerationIsComplete: false,
                captureIsAvailable: false
            )
        }
    }

    static func allProcesses(includeProcessDetails: Bool, includeHMUXScope: Bool) async -> [HmuxTopProcessInfo] {
        let snapshot = await capture(includeProcessDetails: includeProcessDetails, includeHMUXScope: includeHMUXScope, includeResources: false)
        return Array(snapshot.processesByPID.values)
    }

    private static func defaultProcessSnapshotService() -> ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields> {
        AppDelegate.shared?.processSnapshotService ?? makeProcessSnapshotService()
    }
}
