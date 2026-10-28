import Foundation

/// hmux's own transcript strings (Resources/HmuxHome.xcstrings, every app
/// language), for the few places a vendored file says something MessagesLab
/// does not (marked `hmux:` there).
enum HmuxStrings {
    static var notDelivered: String {
        String(localized: "label.notDelivered", defaultValue: "Not Delivered", table: "HmuxHome", bundle: .module)
    }
    static var mayNotHaveBeenDelivered: String {
        String(localized: "label.mayNotHaveBeenDelivered", defaultValue: "May Not Have Been Delivered", table: "HmuxHome", bundle: .module)
    }

    /// Under the field while a send waits for the owner to name its conversation (cx-ebm.55).
    static var waitingForChief: String {
        String(localized: "home.send.waitingForChief", defaultValue: "Waiting for the Chief to connect…", table: "HmuxHome", bundle: .module)
    }
    static var waitingToConnect: String {
        String(localized: "home.send.waitingToConnect", defaultValue: "Waiting to connect…", table: "HmuxHome", bundle: .module)
    }
    /// Home moved the typed text from the cache's Chief conversation to the live Chief.
    static var chiefRestarted: String {
        String(localized: "home.send.chiefRestarted", defaultValue: "The Chief restarted. Press Return to send.", table: "HmuxHome", bundle: .module)
    }

    /// A reply's thread root is not delivered yet (my send still going): the thread view closes.
    static var threadRootNotReady: String {
        String(localized: "home.thread.rootNotReady", defaultValue: "You can reply in this thread once its first message is delivered.",
               table: "HmuxHome", bundle: .module)
    }

    /// The context menu item that cancels my send while it uploads or after it failed.
    static var cancelUpload: String {
        String(localized: "home.menu.cancelUpload", defaultValue: "Cancel Upload", table: "HmuxHome", bundle: .module)
    }

    static var playVideo: String { String(localized: "home.video.play", defaultValue: "Play Video", table: "HmuxHome", bundle: .module) }
    static var pauseVideo: String { String(localized: "home.video.pause", defaultValue: "Pause Video", table: "HmuxHome", bundle: .module) }
    static var openInDefaultApp: String {
        String(localized: "home.menu.openInDefaultApp", defaultValue: "Open in Default App", table: "HmuxHome", bundle: .module)
    }

    /// The reason HomeMapping gives a failed send that reached the owner and
    /// got no answer (`TranscriptItem.mayHaveBeenDelivered`).
    static let mayHaveBeenDeliveredReason = "hmux.mayHaveBeenDelivered"

    /// The label under a failed message of mine (Layout's "failed:" row).
    static func failedLabel(_ status: DeliveryStatus?) -> String {
        if case .failed(let reason) = status, reason == mayHaveBeenDeliveredReason { return mayNotHaveBeenDelivered }
        return notDelivered
    }
}
