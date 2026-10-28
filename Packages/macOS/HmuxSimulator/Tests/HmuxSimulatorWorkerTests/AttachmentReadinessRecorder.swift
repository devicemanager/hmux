import HmuxSimulator

@MainActor
final class AttachmentReadinessRecorder {
    var events: [SimulatorWorkerOutbound] = []
}
