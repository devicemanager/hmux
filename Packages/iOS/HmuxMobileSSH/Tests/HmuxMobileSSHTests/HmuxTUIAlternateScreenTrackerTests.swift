@testable import HmuxMobileSSH
import Foundation
import Testing

/// The phone asks hmux-tui for a fresh snapshot when a program leaves the
/// alternate screen that its last snapshot showed, so the tracker must see
/// every screen switch form, including sequences split across chunks.
@Suite struct HmuxTUIAlternateScreenTrackerTests {
    private func feed(_ tracker: inout HmuxTUIAlternateScreenTracker, _ text: String) -> Bool {
        tracker.feed(Data(text.utf8))
    }

    @Test(arguments: ["1049", "1047", "47"])
    func enterAndLeaveEachMode(mode: String) {
        var tracker = HmuxTUIAlternateScreenTracker()
        #expect(!feed(&tracker, "\u{1B}[?\(mode)hvim"))
        #expect(tracker.isAlternate)
        #expect(feed(&tracker, "\u{1B}[?\(mode)l$ "))
        #expect(!tracker.isAlternate)
    }

    @Test func snapshotModeDumpMarksAlternate() {
        // vt-state emits each differing DEC mode, then the screen contents.
        var tracker = HmuxTUIAlternateScreenTracker()
        feed(&tracker, "\u{1B}]4;0;rgb:00/00/00\u{1B}\\\u{1B}[?25l\u{1B}[?1049h\u{1B}[?2004h~\r\n~\u{1B}[1;1H")
        #expect(tracker.isAlternate)
    }

    @Test func primarySnapshotStaysPrimary() {
        var tracker = HmuxTUIAlternateScreenTracker()
        feed(&tracker, "\u{1B}[?2004h\u{1B}[0;1mhist-1\r\nhist-2\u{1B}[2;7H")
        #expect(!tracker.isAlternate)
    }

    @Test func sequenceSplitAcrossChunks() {
        var tracker = HmuxTUIAlternateScreenTracker(isAlternate: true)
        #expect(!feed(&tracker, "bye\u{1B}"))
        #expect(!feed(&tracker, "[?10"))
        #expect(feed(&tracker, "49l"))
        #expect(!tracker.isAlternate)
    }

    @Test func combinedParametersAndOtherModes() {
        var tracker = HmuxTUIAlternateScreenTracker(isAlternate: true)
        #expect(!feed(&tracker, "\u{1B}[?1000;1006l\u{1B}[?25h\u{1B}[1049l"))
        #expect(tracker.isAlternate, "ANSI mode 1049 without ? is not the alternate screen")
        #expect(feed(&tracker, "\u{1B}[?1;1049l"))
    }

    @Test func fullResetLeavesAlternate() {
        var tracker = HmuxTUIAlternateScreenTracker(isAlternate: true)
        #expect(feed(&tracker, "\u{1B}c"))
        #expect(!tracker.isAlternate)
    }

    @Test func leaveThenReenterInOneChunkStillReportsLeave() {
        var tracker = HmuxTUIAlternateScreenTracker(isAlternate: true)
        #expect(feed(&tracker, "\u{1B}[?1049l$ vim\r\n\u{1B}[?1049h"))
        #expect(tracker.isAlternate)
    }

    @Test func leavingPrimaryIsNotReported() {
        var tracker = HmuxTUIAlternateScreenTracker()
        #expect(!feed(&tracker, "\u{1B}[?1049l\u{1B}c"))
        #expect(!tracker.isAlternate)
    }

    @Test func canceledOrOversizedSequencesAreIgnored() {
        var tracker = HmuxTUIAlternateScreenTracker(isAlternate: true)
        #expect(!feed(&tracker, "\u{1B}[?10\u{18}49l"))
        #expect(!feed(&tracker, "\u{1B}[?" + String(repeating: "1;", count: 40) + "1049l"))
        #expect(tracker.isAlternate)
    }
}
