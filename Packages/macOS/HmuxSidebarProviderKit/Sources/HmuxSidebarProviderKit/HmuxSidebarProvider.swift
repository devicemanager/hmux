import Foundation

/// In-process sidebar provider used by HMUX-owned sidebar presentations.
public protocol HmuxSidebarProvider: Sendable {
    /// Stable metadata describing the provider in selection UI.
    var descriptor: HmuxSidebarProviderDescriptor { get }

    /// Builds a render model from the latest sidebar snapshot.
    func render(snapshot: HmuxSidebarProviderSnapshot) -> HmuxSidebarProviderRenderModel
}
