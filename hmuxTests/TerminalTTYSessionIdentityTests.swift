import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

struct TerminalTTYSessionIdentityTests {
    @Test("rejects non-terminal device names without opening them")
    func rejectsNonTerminalDevice() {
        #expect(TerminalTTYSessionIdentity.sessionLeaderPID(forDeviceNamed: "null") == nil)
    }

    @Test("rejects malformed device names")
    func rejectsMalformedDeviceName() {
        #expect(TerminalTTYSessionIdentity.sessionLeaderPID(forDeviceNamed: "") == nil)
        #expect(TerminalTTYSessionIdentity(ttyName: "not a tty") == nil)
    }
}
