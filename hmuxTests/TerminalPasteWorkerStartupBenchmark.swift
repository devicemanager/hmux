import HmuxTerminal
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// Repeats #12773's valid, stale-generation request with fresh and identical argv.
extension TerminalPlainTextPasteStartupTests {
    @Test
    func freshAndRepeatedWorkerArguments() async throws {
        let app = try #require(Bundle.main.executableURL)
        let helper = try #require(Bundle.main.url(forResource: "hmux-paste-text-worker", withExtension: nil, subdirectory: "bin"))
        for (binary, mode, kind) in [
            (app, "--hmux-paste-preparation-worker", "full"),
            (helper, "--hmux-plain-text-paste-worker", "text")
        ] {
            for directoryIndex in 0..<2 {
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("hmux-paste-preparation-\(UUID())")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                       attributes: [.posixPermissions: 0o700])
                defer { try? FileManager.default.removeItem(at: directory) }
                let request: TerminalPastePreparationRequest
                if kind == "full" {
                    request = .init(snapshot: TerminalPasteboardContentsCaptureRequest(
                        pasteboardName: "hmux-startup-\(UUID())", changeCount: -1, maximumByteCount: 1024
                    ))
                } else {
                    request = .init(pasteboard: .init(pasteboardName: "hmux-startup-\(UUID())", changeCount: -1),
                                    mode: .paste, destination: .terminal)
                }
                try JSONEncoder().encode(request).write(to: directory.appendingPathComponent("request.json"))
                for repetition in 0..<2 {
                    let process = TerminalPastePreparationProcess(
                        executableURL: binary,
                        arguments: [mode, "--hmux-paste-preparation-working-directory", directory.path],
                        environment: ProcessInfo.processInfo.environment
                    )
                    let started = ContinuousClock.now
                    let status = try await process.run()
                    let elapsed = started.duration(to: .now).components
                    let milliseconds = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
                    #expect(status == 0)
                    let response = try JSONDecoder().decode(TerminalPastePreparationWorkerResponse.self,
                        from: Data(contentsOf: directory.appendingPathComponent("response.json")))
                    #expect(response.ownedTemporaryImageNames.isEmpty)
                    #expect(response.textPayload == nil)
                    print("PASTE_STARTUP kind=\(kind) directory=\(directoryIndex) repetition=\(repetition) duration_ms=\(milliseconds) status=\(status) os=\(ProcessInfo.processInfo.operatingSystemVersionString)")
                }
            }
        }
    }
}
