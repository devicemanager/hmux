import Foundation

/// Seconds between `vm.status` polls while `hmux vm` waits for a machine.
///
/// `HMUX_VM_WAIT_POLL_SECONDS` overrides the default so tests against a mock
/// socket do not wait out the real cadence. This file is compiled into both
/// the bundled CLI and hmuxCLITests (the CLI is a tool target that tests
/// cannot import), so it must not reference CLI-private symbols.
enum VMReadyPollInterval {
    static let defaultSeconds: TimeInterval = 3

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TimeInterval {
        guard let raw = environment["HMUX_VM_WAIT_POLL_SECONDS"],
              let parsed = TimeInterval(raw),
              parsed.isFinite,
              parsed >= 0.01,
              parsed <= defaultSeconds else {
            return defaultSeconds
        }
        return parsed
    }
}
