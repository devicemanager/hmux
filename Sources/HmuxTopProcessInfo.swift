import HmuxFoundation
import Foundation
import HmuxFoundation

struct HmuxTopProcessInfo: Sendable {
    let pid: Int
    let processIdentity: AgentPIDProcessIdentity?
    let parentPID: Int
    let name: String
    let path: String?
    let ttyDevice: Int64?
    let hmuxWorkspaceID: UUID?
    let hmuxSurfaceID: UUID?
    let hmuxAttributionReason: String?
    let processGroupID: Int?
    let terminalProcessGroupID: Int?
    var cpuPercent: Double
    let memoryBytes: Int64
    let memorySource: HmuxTopProcessMemorySource
    let residentBytes: Int64
    let residentMemorySource: HmuxTopProcessMemorySource
    let virtualBytes: Int64
    let threadCount: Int

    init(
        pid: Int,
        processIdentity: AgentPIDProcessIdentity? = nil,
        parentPID: Int,
        name: String,
        path: String?,
        ttyDevice: Int64?,
        hmuxWorkspaceID: UUID?,
        hmuxSurfaceID: UUID?,
        hmuxAttributionReason: String?,
        processGroupID: Int?,
        terminalProcessGroupID: Int?,
        cpuPercent: Double,
        memoryBytes: Int64? = nil,
        memorySource: HmuxTopProcessMemorySource? = nil,
        residentBytes: Int64,
        residentMemorySource: HmuxTopProcessMemorySource = .residentSize,
        virtualBytes: Int64,
        threadCount: Int
    ) {
        self.pid = pid
        self.processIdentity = processIdentity
        self.parentPID = parentPID
        self.name = name
        self.path = path
        self.ttyDevice = ttyDevice
        self.hmuxWorkspaceID = hmuxWorkspaceID
        self.hmuxSurfaceID = hmuxSurfaceID
        self.hmuxAttributionReason = hmuxAttributionReason
        self.processGroupID = processGroupID
        self.terminalProcessGroupID = terminalProcessGroupID
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes ?? residentBytes
        self.memorySource = memorySource
            ?? (memoryBytes == nil ? .residentSize : .physicalFootprint)
        self.residentBytes = residentBytes
        self.residentMemorySource = residentMemorySource
        self.virtualBytes = virtualBytes
        self.threadCount = threadCount
    }

    var isTerminalForegroundProcessGroup: Bool {
        guard let processGroupID, let terminalProcessGroupID else { return false }
        return processGroupID == terminalProcessGroupID
    }
}
