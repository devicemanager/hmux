#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// Safety: one socket worker writes once, and the test reads only after its continuation resumes.
final class PiFeedV2CallResultBox: @unchecked Sendable {
    var value: TerminalController.V2CallResult?
}
