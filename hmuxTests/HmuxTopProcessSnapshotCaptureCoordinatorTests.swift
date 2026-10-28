import HmuxFoundation
import Foundation
import Testing
#if canImport(hmux_DEV)
@testable import hmux_DEV
#else
@testable import hmux
#endif

@Suite(.serialized)
struct HmuxTopProcessSnapshotCaptureCoordinatorTests {
    @Test("Same synthetic pipeline: eight independent censuses versus one shared census")
    func concurrentRequestsCoalesce() async throws {
        let baselineReader = SyntheticProcessSnapshotReader()
        let baselineSampler = HmuxTopProcessSampler(reader: baselineReader)
        let baselineStart = ProcessSnapshotMeasurement()
        let baseline = try await withThrowingTaskGroup(of: HmuxTopProcessCapture.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try baselineSampler.enrich(baselineSampler.capture(), fields: [.details, .scope, .resources])
                }
            }
            var values: [HmuxTopProcessCapture] = []
            for try await value in group { values.append(value) }
            return values
        }
        ProcessSnapshotMeasurement().report("independent", since: baselineStart)
        let before = baselineReader.state.withLock { $0.counts }
        print("PROCESS_SNAPSHOT_FIXTURE phase=independent enumerations=\(before.enumerations) bsd=\(before.bsd) task=\(before.task) rusage=\(before.rusage) paths=\(before.paths) scope=\(before.scope) identity=\(before.identity)")
        #expect(before.enumerations == 8)
        #expect(before.bsd == 32768 && before.task == 32768 && before.rusage == 32768)
        #expect(before.paths == 32768 && before.scope == 32768)
        #expect(baseline.count == 8)

        let reader = SyntheticProcessSnapshotReader()
        let sampler = HmuxTopProcessSampler(reader: reader)
        let began = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let service = ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields>(
            now: { reader.now() },
            capture: {
                began.continuation.yield(())
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
                return try sampler.capture()
            },
            enrich: { try sampler.enrich($0, fields: $1) }
        )
        let start = ProcessSnapshotMeasurement()
        let first = Task { await HmuxTopProcessSnapshot.captureCached(includeProcessDetails: true, maximumAge: 60, service: service) }
        var iterator = began.stream.makeAsyncIterator()
        _ = await iterator.next()
        let peers = (0..<7).map { _ in
            Task { await HmuxTopProcessSnapshot.captureCached(includeProcessDetails: true, maximumAge: 60, service: service) }
        }
        await reader.waitForAdmissions(8)
        release.continuation.yield(())
        release.continuation.finish()
        let value = await first.value
        for peer in peers { #expect(await peer.value === value) }
        ProcessSnapshotMeasurement().report("shared", since: start)
        let counts = reader.state.withLock { $0.counts }
        print("PROCESS_SNAPSHOT_FIXTURE processes=4096 workspaces=125 surfaces=427 callers=8 enumerations=\(counts.enumerations) bsd=\(counts.bsd) task=\(counts.task) rusage=\(counts.rusage) names=\(counts.names) paths=\(counts.paths) scope=\(counts.scope) identity=\(counts.identity)")
        #expect(counts.enumerations == 1)
        #expect(counts.bsd == 4096 && counts.task == 4096 && counts.rusage == 4096)
        #expect(counts.paths == 4096 && counts.scope == 4096)
        #expect(value.processesByPID.count == 4096)
        // Keep the measured baseline records alive until after both allocator samples.
        withExtendedLifetime(baseline) {}
        began.continuation.finish()
    }

    @Test func minimalCensusNeverReadsPathsOrScope() async throws {
        let reader = SyntheticProcessSnapshotReader(count: 1000)
        let sampler = HmuxTopProcessSampler(reader: reader)
        let value = try await Task.detached { try sampler.capture() }.value
        let counts = reader.state.withLock { $0.counts }
        #expect(counts.names == 0 && counts.paths == 0 && counts.scope == 0)
        #expect(counts.task == 0 && counts.rusage == 0)
        #expect(!value.snapshot.hasHMUXScope)
        #expect(!value.snapshot.includesResources)
        #expect(value.snapshot.processesByPID.values.allSatisfy { $0.path == nil })
    }

    @Test func enrichmentPreservesMissingAndTruncatedListingMetadata() async throws {
        let reader = SyntheticProcessSnapshotReader(count: 1000)
        reader.state.withLock { $0.missingPID = 123; $0.complete = false }
        let sampler = HmuxTopProcessSampler(reader: reader)
        let value = try await Task.detached {
            try sampler.enrich(sampler.capture(), fields: [.details, .scope, .resources])
        }.value
        #expect(!value.snapshot.enumerationIsComplete)
        #expect(value.snapshot.enumerationMissingProcessCount == 1)
        #expect(value.snapshot.process(pid: 123) == nil)
    }

    @Test func enrichmentRejectsReusedPIDAndNeverRecensuses() async throws {
        let reader = SyntheticProcessSnapshotReader(count: 1000)
        let sampler = HmuxTopProcessSampler(reader: reader)
        let base = try await Task.detached { try sampler.capture() }.value
        reader.state.withLock { $0.replacedPID = 123 }
        let rich = try await Task.detached { try sampler.enrich(base, fields: [.details, .scope, .resources]) }.value
        #expect(rich.snapshot.process(pid: 123) == nil)
        #expect(!rich.snapshot.enumerationIsComplete)
        #expect(rich.snapshot.enumerationMissingProcessCount == 1)
        #expect(reader.state.withLock { $0.counts.enumerations } == 1)
        #expect(reader.state.withLock { $0.counts.paths } == 999)
    }
    @MainActor @Test func mainActorConsumerSuspendsWhileCensusAndEnrichmentRunOffMain() async {
        let reader = SyntheticProcessSnapshotReader(count: 100)
        let sampler = HmuxTopProcessSampler(reader: reader)
        let service = ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields>(
            now: { reader.now() },
            capture: { try sampler.capture() }, enrich: { try sampler.enrich($0, fields: $1) }
        )
        let value = await HmuxTopProcessSnapshot.capture(includeProcessDetails: true, service: service)
        #expect(value.processesByPID.count == 100)
        #expect(reader.state.withLock { $0.mainThreadReads } == 0)
    }

    @Test func freshCensusReprobesAbsentScopeAfterSamePIDExec() async {
        let reader = SyntheticProcessSnapshotReader(count: 100)
        reader.state.withLock { $0.hasScope = false }
        let sampler = HmuxTopProcessSampler(reader: reader)
        let service = ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields>(
            now: { reader.now() },
            capture: { try sampler.capture() }, enrich: { try sampler.enrich($0, fields: $1) }
        )
        let first = await HmuxTopProcessSnapshot.capture(service: service)
        #expect(first.hmuxScopedProcesses().isEmpty)
        let cached = await HmuxTopProcessSnapshot.captureCached(maximumAge: 5, service: service)
        #expect(cached === first)
        #expect(reader.state.withLock { $0.counts.scope } == 100)
        reader.state.withLock { $0.hasScope = true }
        let fresh = await HmuxTopProcessSnapshot.capture(service: service)
        #expect(fresh.hmuxScopedProcesses().count == 100)
        #expect(reader.state.withLock { $0.counts.scope } == 200)
    }

    @MainActor
    @Test("A slow fresh quit census returns at its deadline")
    func freshQuitCensusReturnsAtDeadline() async {
        let reader = SyntheticProcessSnapshotReader(count: 100)
        let sampler = HmuxTopProcessSampler(reader: reader)
        let began = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let service = ProcessSnapshotService<HmuxTopProcessCapture, HmuxTopProcessFields>(
            capture: {
                began.continuation.yield(())
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
                return try sampler.capture()
            },
            enrich: { try sampler.enrich($0, fields: $1) }
        )

        // Fire the deadline only once the census is in progress. An immediate
        // deadline can win before the utility worker reaches the provider; the
        // cancelled worker then never calls `capture`, so a test that waited
        // for `began` would hang instead of exercising a slow census.
        let result = await ProcessDetectedResumeIndexes.loadFreshWithDeadline(
            processSnapshotService: service,
            deadline: .milliseconds(1),
            sleepUntilDeadline: { _ in
                var iterator = began.stream.makeAsyncIterator()
                return await iterator.next() != nil
            }
        )

        #expect(result == nil)
        release.continuation.finish()
    }

}
