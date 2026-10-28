import HmuxRemoteSession

@MainActor
final class CleanupRequestRecorder {
    var requests: [NativeSSHControlMasterCleanupRequest] = []
}
