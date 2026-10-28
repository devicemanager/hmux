import HmuxCore
import HmuxRemoteWorkspace
import Foundation
@testable import HmuxRemoteSession

struct IntentionalCleanupBuildInfo: RemoteSessionBuildInfoProviding {
    func appVersion() -> String? { nil }
    func embeddedDaemonManifest() -> WorkspaceRemoteDaemonManifest? { nil }
    func executableDirectoryURL() -> URL? { nil }
}
