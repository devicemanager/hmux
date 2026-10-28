import Foundation

/// The Chief's question card, Cloud provisioning row and result card
/// (Resources/HmuxHome.xcstrings).
extension HmuxStrings {
    /// VoiceOver's name for the question card.
    static var questionRole: String {
        String(localized: "home.question.role", defaultValue: "Question", table: "HmuxHome", bundle: .module)
    }
    /// The card's primary button when the Chief named none.
    static var questionSubmit: String {
        String(localized: "home.question.submit", defaultValue: "Submit", table: "HmuxHome", bundle: .module)
    }
    /// A Chief question card the user answered by writing instead (the receipt row).
    static var questionAnsweredInChat: String {
        String(localized: "home.question.answeredInChat", defaultValue: "Answered in chat", table: "HmuxHome", bundle: .module)
    }
    static var questionCancelled: String {
        String(localized: "home.question.cancelled", defaultValue: "Cancelled", table: "HmuxHome", bundle: .module)
    }

    /// The provisioning row while the machine is created; `elapsed` is a short duration ("40s").
    static func cloudCreating(_ elapsed: String) -> String {
        String(localized: "home.cloud.creating", defaultValue: "Creating cloud machine… \(elapsed)", table: "HmuxHome", bundle: .module)
    }
    static var cloudReady: String {
        String(localized: "home.cloud.ready", defaultValue: "Cloud machine ready", table: "HmuxHome", bundle: .module)
    }
    static var cloudFailed: String {
        String(localized: "home.cloud.failed", defaultValue: "Couldn't create cloud machine", table: "HmuxHome", bundle: .module)
    }
    /// The result card's action.
    static var cloudOpenWorkspace: String {
        String(localized: "home.cloud.openWorkspace", defaultValue: "Open Workspace", table: "HmuxHome", bundle: .module)
    }
    /// The result card's live-display action.
    static var cloudOpenDesktop: String {
        String(localized: "home.cloud.openDesktop", defaultValue: "Open Desktop", table: "HmuxHome", bundle: .module)
    }
    /// VoiceOver's name for the result card.
    static var cloudResultRole: String {
        String(localized: "home.cloud.resultRole", defaultValue: "Cloud workspace", table: "HmuxHome", bundle: .module)
    }
    static var cloudStatusWorking: String {
        String(localized: "home.cloud.status.working", defaultValue: "Agent working", table: "HmuxHome", bundle: .module)
    }
    static var cloudStatusReady: String {
        String(localized: "home.cloud.status.ready", defaultValue: "Ready", table: "HmuxHome", bundle: .module)
    }
    /// The result card's state while the agent waits for the user to sign in.
    static var cloudStatusNeedsSignIn: String {
        String(localized: "home.cloud.status.needsSignIn", defaultValue: "Needs sign-in", table: "HmuxHome", bundle: .module)
    }
    /// The result card's secondary action: pause the machine (the Chief asks first).
    static var cloudStopMachine: String {
        String(localized: "home.cloud.stopMachine", defaultValue: "Stop Machine", table: "HmuxHome", bundle: .module)
    }
    /// What the Stop Machine button sends the Chief: the machine's name and its id.
    static func cloudStopMachineRequest(_ name: String, _ machine: String) -> String {
        String(localized: "home.cloud.stopMachineRequest", defaultValue: "Stop cloud machine \(name) (\(machine))",
               table: "HmuxHome", bundle: .module)
    }
    static var cloudStatusFailed: String {
        String(localized: "home.cloud.status.failed", defaultValue: "Failed", table: "HmuxHome", bundle: .module)
    }
}
