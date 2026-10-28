@testable import HmuxSimulator
import Foundation

func simulatorFrameTransportDescriptor(
    _ identifier: UInt32
) -> SimulatorFrameTransportDescriptor {
    let layout = try! SimulatorFrameSharedMemoryLayout(width: 390, height: 844)
    return SimulatorFrameTransportDescriptor(
        sharedMemoryName: String(
            format: "/hmux-sim-frame-%012llx",
            UInt64(identifier)
        ),
        width: 390,
        height: 844,
        bytesPerRow: layout.bytesPerRow,
        slotCount: layout.slotCount,
        sharedMemoryByteCount: layout.totalByteCount
    )
}
