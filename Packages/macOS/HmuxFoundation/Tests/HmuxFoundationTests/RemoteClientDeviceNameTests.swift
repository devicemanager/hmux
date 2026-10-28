import HmuxFoundation
import Testing

struct RemoteClientDeviceNameTests {
    @Test(arguments: [
        ("MacBook.local", "hmux-MacBook"),
        ("Austin's MacBook.local", "hmux-Austin-s-MacBook"),
        ("build-box.example.com", "hmux-build-box"),
        ("", "hmux-mac"),
        (String(repeating: "x", count: 100), "hmux-" + String(repeating: "x", count: 40))
    ])
    func keepsTheExistingRemoteLabelFormat(hostName: String, expected: String) {
        #expect(RemoteClientDeviceName(hostName: hostName).value == expected)
    }
}
