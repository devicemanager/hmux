import Foundation
import HmuxMemoryPressure

struct MemoryPressureStateEvaluation: Equatable, Sendable {
    let previousSeverity: MemoryPressureSeverity
    let snapshot: MemoryPressureSnapshot
    let didTransition: Bool
    let didBecomePersistentCritical: Bool
}
