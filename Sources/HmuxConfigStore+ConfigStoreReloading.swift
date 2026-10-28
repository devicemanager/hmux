import HmuxTerminalCore

/// Lets `HmuxConfigStoreReloadCoordinator` drive per-window config reloads through a
/// protocol seam. `HmuxConfigStore`'s existing `loadAll()` already satisfies the
/// requirement, so this conformance is empty.
extension HmuxConfigStore: HmuxConfigStoreReloading {}
