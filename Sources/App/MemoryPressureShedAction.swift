import Foundation
import HmuxMemoryPressure

struct MemoryPressureShedAction: Equatable, Sendable {
    let responderID: String
    let severity: MemoryPressureSeverity
    let reclaimedItemCount: Int
    let estimatedBytes: UInt64?
    let detail: String?
    let performedAt: Date
}
