#if DEBUG
import Testing
@testable import HmuxMobileShellReleaseGateSupport

struct MobileIrohReleaseGateArtifactPreparationTests {
    @Test
    func completionMarkerCannotAppearInTheEchoedCommand() {
        let preparation = MobileIrohReleaseGateArtifactPreparation.make(
            path: "/tmp/hmux-iroh-gate-test.bin",
            suffixText: "HMUX_IROH_ARTIFACT_TEST",
            marker: "HMUX_IROH_GATE_TEST"
        )

        #expect(preparation.completionMarker.hasPrefix("HMUX_IROH_ARTIFACT_READY_"))
        #expect(!preparation.command.contains(preparation.completionMarker))
    }

    @Test
    func readinessRequiresTwoStableStatObservations() {
        #expect(MobileIrohReleaseGateArtifactPreparation.requiredStableStatObservations == 2)
    }

    @Test
    func artifactPathIsPublishedOnItsOwnLineBeforeCompletion() {
        let path = "/tmp/hmux-iroh-gate-test.bin"
        let preparation = MobileIrohReleaseGateArtifactPreparation.make(
            path: path,
            suffixText: "HMUX_IROH_ARTIFACT_TEST",
            marker: "HMUX_IROH_GATE_TEST"
        )

        let pathPublication = "printf '\\n%s\\n' '\(path)'"
        let completionPublication = "printf '\\n%s%s\\n'"
        let pathRange = preparation.command.range(of: pathPublication)
        let completionRange = preparation.command.range(of: completionPublication)

        #expect(pathRange != nil)
        #expect(completionRange != nil)
        if let pathRange, let completionRange {
            #expect(pathRange.upperBound < completionRange.lowerBound)
        }
    }
}
#endif
