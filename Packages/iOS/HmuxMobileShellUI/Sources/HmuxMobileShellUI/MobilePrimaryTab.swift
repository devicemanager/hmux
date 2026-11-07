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
    /// Whether the tab bar offers Cloud. The composition root supplies Cloud
    /// content only when the build has Cloud; a local-only build has none, so
    /// it gets no Cloud tab rather than an empty one.
    static func showsCloudTab(cloudTabContent: MobileCloudTabContent?) -> Bool {
        cloudTabContent != nil
    }
}
#endif
