import Testing
@testable import HmuxSimulatorWorker

@Suite("Simulator worker entrypoint")
struct HmuxSimulatorWorkerNamespaceTests {
    @Test("DEVELOPER_DIR wins over xcode-select")
    func developerDirectoryOverride() {
        let directory = SimulatorDeveloperDirectoryResolver().resolve(
            environment: ["DEVELOPER_DIR": "/Applications/Xcode-beta.app/Contents/Developer"]
        )

        #expect(directory == "/Applications/Xcode-beta.app/Contents/Developer")
    }
}
