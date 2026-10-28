# hmux Go SDK

Package `hmux` exposes the typed `hmux.protocol/2` resource API. Package
`hmux/raw` preserves the private protocol-v12 API.

Install the released nested module with its semantic-version tag:

```bash
go get github.com/manaflow-ai/cmux/cmux-tui/bindings/go@v1.0.0
```

```go
client, err := hmux.NewClient(ctx, hmux.ClientOptions{})
if err != nil {
	log.Fatal(err)
}
defer client.Close(context.Background())

session := client.
	Machine(hmux.SelectCurrent[hmux.MachineID]()).
	Session(hmux.SelectCurrent[hmux.SessionID]())
workspace := session.Workspace(hmux.SelectCurrent[hmux.WorkspaceID]())
result, err := workspace.Run(ctx, hmux.WorkspaceRunOptions{
	Command: hmux.Exact("printf", "hello\n"),
})

agent, err := session.ReportAgent(ctx, hmux.AgentReportOptions{
	TerminalID: result.Value.Terminal,
	State:      hmux.AgentStateWorking,
	Source:     hmux.AgentReportSourceSocket,
})
```

`Exact` preserves argv without shell interpretation. `Shell` requests explicit
server-side shell execution. Resource handles do not own remote resources.
Only `Client` and typed streams require explicit close or cancellation.
`Session.ReportAgent` publishes the first agent state for a terminal and
returns the typed agent snapshot without requiring an earlier agent listing.

Mutations use caller-provided idempotency keys or keys generated from 128 bits
of secure random data. The client never retries mutations. `Decimal` encodes
the full unsigned 64-bit range as a canonical JSON string. Renderer grants
redact their values from formatted output.

Each `frame` item from `Browser.Attach` includes `PointerFrameSeq *Decimal`.
`nil` means the frame cannot authorize pointer input. Pass a non-nil frame's
exact value to `BrowserInputMouseOptions.PointerFrameSeq` or
`BrowserInputWheelOptions.PointerFrameSeq`; both inputs always encode the token
as an unsigned decimal string.

`ClientOptions.DialContext` supports injected transports and tests. The default
transport uses a Unix session socket, with a Windows-compatible build fallback
that requires injection.

An empty `ClientOptions.Session` with `SessionSet: false` is omitted and selects
the `main` session. Set `SessionSet: true` when session text came from user input;
an explicitly empty session is then rejected before socket discovery. Existing
non-empty `Session` values remain explicit without requiring `SessionSet`.
