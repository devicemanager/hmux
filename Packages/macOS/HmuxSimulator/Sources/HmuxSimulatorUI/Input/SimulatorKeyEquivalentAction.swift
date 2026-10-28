import HmuxSimulator

enum SimulatorKeyEquivalentAction: Equatable {
    case messages([SimulatorWorkerInbound])
}
