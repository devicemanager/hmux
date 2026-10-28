import Foundation

enum ControlSidebarAgentLifecycleRegistryScope: Sendable {
    case project(String?)
    case globalOnly

    func loadRegistry(
        homeDirectory: String = NSHomeDirectory(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> HmuxVaultAgentRegistry {
        switch self {
        case .project(let workingDirectory):
            return HmuxVaultAgentRegistry.load(
                homeDirectory: homeDirectory,
                workingDirectory: workingDirectory,
                environment: environment,
                fileManager: fileManager
            )
        case .globalOnly:
            return HmuxVaultAgentRegistry.load(
                homeDirectory: homeDirectory,
                environment: [:],
                fileManager: fileManager
            )
        }
    }
}
