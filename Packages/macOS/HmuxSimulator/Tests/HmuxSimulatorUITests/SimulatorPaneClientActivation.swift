import HmuxSimulator

struct SimulatorPaneClientActivation: Sendable {
    let id: String
    let geometry: SimulatorSurfaceGeometry?
}
