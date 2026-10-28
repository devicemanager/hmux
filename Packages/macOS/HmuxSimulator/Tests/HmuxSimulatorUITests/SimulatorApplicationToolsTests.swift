import HmuxSimulator
import Testing

@testable import HmuxSimulatorUI

@Suite("Simulator application picker")
struct SimulatorApplicationToolsTests {
    @Test("Application rows remain independent from later inventory updates")
    func applicationRowsAreImmutableSnapshots() {
        var applications = [application(id: "dev.hmux.one", name: "One")]
        let rows = simulatorApplicationPickerRows(applications)

        applications[0] = application(id: "dev.hmux.one", name: "Changed")

        #expect(rows == [SimulatorApplicationPickerRow(
            id: "dev.hmux.one",
            displayName: "One"
        )])
    }

    private func application(id: String, name: String) -> SimulatorInstalledApplication {
        SimulatorInstalledApplication(
            id: id,
            name: name,
            displayName: name,
            executableName: name,
            path: "/Applications/\(name).app",
            applicationType: "User"
        )
    }
}
