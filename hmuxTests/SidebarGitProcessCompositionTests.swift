import Testing
@testable import HmuxGit

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
@Suite(.serialized)
struct SidebarGitProcessCompositionTests {
    @Test func nonactivatingWindowsShareTheProcessRequestCoordinator() throws {
        let previousAppDelegate = AppDelegate.shared
        let appDelegate = AppDelegate()
        let firstWindowId = appDelegate.createMainWindow(shouldActivate: false)
        let secondWindowId = appDelegate.createMainWindow(shouldActivate: false)
        defer {
            _ = appDelegate.closeMainWindow(windowId: secondWindowId, recordHistory: false)
            _ = appDelegate.closeMainWindow(windowId: firstWindowId, recordHistory: false)
            AppDelegate.shared = previousAppDelegate
        }

        let firstManager = try #require(appDelegate.tabManagerFor(windowId: firstWindowId))
        let secondManager = try #require(appDelegate.tabManagerFor(windowId: secondWindowId))
        let processCoordinator = appDelegate.pullRequestProbeService.requestCoordinator

        #expect(firstManager.pullRequestProbeService.requestCoordinator === processCoordinator)
        #expect(secondManager.pullRequestProbeService.requestCoordinator === processCoordinator)
    }
}
