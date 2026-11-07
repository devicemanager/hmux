#if os(iOS)
/// The mobile app's primary destinations and transient search selection.
enum MobilePrimaryTab: Hashable {
    /// Messages-style conversation home. It is only mounted when the
    /// selected Mac advertises the Chief mobile surface.
    case home
    case workspaces
    case feed
    case notifications
    case cloud
    case search
}

extension MobilePrimaryTab {
    /// Whether the tab bar offers Cloud, given the content the composition
    /// root supplied.
    static func showsCloudTab(cloudTabContent: MobileCloudTabContent?) -> Bool {
        true
    }
}
#endif
