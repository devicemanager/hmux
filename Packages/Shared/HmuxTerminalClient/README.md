# HmuxTerminalClient

Swift face of `hmux-tui/crates/hmux-terminal-client`: connect to a hmux daemon
by route with a persistent device identity, optionally through an in-process
WireGuard tunnel, list or create terminals, and receive raw terminal bytes for
an embedding libghostty view.

`HmuxTerminalClientKit` wraps the C ABI. `HmuxTerminalClientModel` is pure
Swift (result decoding, output event mapping) and carries the unit tests, so
`HMUX_TERMINAL_CLIENT_MODEL_ONLY=1 swift test --package-path Packages/Shared/HmuxTerminalClient`
runs them without the binary (the variable drops the Kit and binary targets
from the manifest for that invocation).

The binary is `CmuxTerminalClient.xcframework`, built by
`.github/workflows/hmux-terminal-client-xcframework.yml` and pinned in
`Package.swift` by release tag and SwiftPM checksum. To try an unreleased
build, download the workflow artifact, unzip `CmuxTerminalClient.xcframework`
next to `Package.swift` (gitignored), and the manifest picks it up. Set
`HMUX_TERMINAL_CLIENT_FORCE_REMOTE_XCFRAMEWORK=1` to ignore a local copy.

Usage:

```swift
let tunnel = try WireGuardNet(wgQuickConfig: configText)
let client = try TerminalClient.connect(
    route: "ws://[fd7a::10]:1337/v1/link",
    stateDirectory: appSupport.appendingPathComponent("hmux-remote"),
    deviceName: "iPhone",
    invitation: firstContactInvitationURI,
    wireGuard: tunnel)
client.setOutputHandler { event in /* feed libghostty */ }
let id = try client.createTerminal(name: "phone")
try client.attach(terminalID: id)
client.send(Data("ls\n".utf8))
```
