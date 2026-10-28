import HmuxWorkspaces
import Foundation
import Testing

#if canImport(hmux_DEV)
    @testable import hmux_DEV
#elseif canImport(hmux)
    @testable import hmux
#endif

@Suite("Workspace todo notification regressions", .serialized)
@MainActor
struct WorkspaceTodoNotificationRegressionTests {
    @Test
    func settingWorkspaceStatusDoneDoesNotCreateNotification() {
        let store = TerminalNotificationStore.shared
        let previousShared = AppDelegate.shared
        let appDelegate = previousShared ?? AppDelegate()
        let originalNotificationStore = appDelegate.notificationStore

        AppDelegate.shared = appDelegate
        appDelegate.notificationStore = store
        store.replaceNotificationsForTesting([])
        store.configureNotificationDeliveryHandlerForTesting { _, _ in }
        store.configureSuppressedNotificationFeedbackHandlerForTesting { _, _ in }
        defer {
            store.replaceNotificationsForTesting([])
            store.resetNotificationDeliveryHandlerForTesting()
            store.resetSuppressedNotificationFeedbackHandlerForTesting()
            appDelegate.notificationStore = originalNotificationStore
            AppDelegate.shared = previousShared
        }

        let workspace = Workspace(title: "Done status")
        workspace.setTaskStatusOverride(.done)

        #expect(workspace.effectiveTaskStatus == .done)
        #expect(store.notifications.isEmpty)
    }
}
