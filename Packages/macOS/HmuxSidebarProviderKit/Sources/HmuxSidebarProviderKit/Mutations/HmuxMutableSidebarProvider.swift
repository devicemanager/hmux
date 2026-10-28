import Foundation

/// Provider that can both render sidebar state and handle host mutations.
public protocol HmuxMutableSidebarProvider: HmuxContextualSidebarProvider {
    /// Handles a mutation against the latest sidebar snapshot.
    func handle(
        _ mutation: HmuxSidebarProviderMutation,
        snapshot: HmuxSidebarProviderSnapshot
    ) throws -> HmuxSidebarProviderCommandResult
}
