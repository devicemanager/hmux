import HmuxMobileShellModel

/// The source that completed a concurrent task model refresh.
enum MobileTaskModelRefreshEvent: Sendable {
    case host(MobileTaskModelHostRefreshResult)
    case backend(MobileTaskModelListResult?)
}
