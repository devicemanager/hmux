#if os(iOS)
import HmuxAgentChat
import Foundation
import Testing

@testable import HmuxMobileShellUI

@Suite
struct TerminalArtifactGalleryFailureTests {
    @Test
    func preservesSpecificFailureMeaning() {
        #expect(TerminalArtifactGalleryFailure(error: ChatArtifactError.macUnreachable).error == .macUnreachable)
        #expect(TerminalArtifactGalleryFailure(error: ChatArtifactError.sessionNotFound).error == .sessionNotFound)
        #expect(TerminalArtifactGalleryFailure(error: ChatArtifactError.fileNotFound).error == .fileNotFound)
        #expect(TerminalArtifactGalleryFailure(error: CocoaError(.fileReadUnknown)).error == .loadFailed)
    }
}
#endif
