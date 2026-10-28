#if DEBUG
import HmuxSimulator

extension SimulatorPaneCoordinator {
    /// Terminates the isolated renderer so containment recovery can be verified.
    public func terminateRenderer() {
        enqueue(.terminateRenderer)
    }
}
#endif
