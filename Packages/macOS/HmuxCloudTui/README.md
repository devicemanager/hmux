# HmuxCloudTui

The hmux-tui client transport for cloud terminals: request and argv builders for the daemon, the manual-IO socket (framing, decoding, input routing, resize coalescing), the manual-mirror deadlines and watchdog, the remote color document, and the on-disk client paths. No app imports; depends on `HmuxSurfaceCatalogModel` (cursor and projection targets), `HmuxTerminal` (raw sizing samples and manual input), `HmuxCloudImagePaste` and `HmuxFoundation`.

```swift
import HmuxCloudTui

var scheduler = CloudTuiManualIOResizeScheduler()
if let grid = CloudTuiManualIOGrid(columns: 120, rows: 40),
   let send = scheduler.sample(grid, canSend: true) {
    connection.send(CloudTuiManualIOCommand().resize(surfaceID: id, columns: send.columns, rows: send.rows))
}
```

## Moved files

From `Sources/Cloud/`: `CloudTuiClientPaths.swift`, `CloudTuiCommandLine.swift`, `CloudTuiCommandLine+Placement.swift`, `CloudTuiLegacySnapshotParser.swift`, `CloudTuiManualIOCommand.swift`, `CloudTuiManualIOConnection.swift`, `CloudTuiManualIODescriptorLease.swift`, `CloudTuiManualIOFrame.swift`, `CloudTuiManualIOFrameDecoder.swift`, `CloudTuiManualIOGrid.swift`, `CloudTuiManualIOGrid+SizingSample.swift`, `CloudTuiManualIOInputRouter.swift`, `CloudTuiManualIOResizeScheduler.swift`, `CloudTuiManualMirrorDeadlines.swift`, `CloudTuiManualMirrorPhase.swift`, `CloudTuiManualMirrorRequestKind.swift`, `CloudTuiManualMirrorWatchdog.swift`, `CloudTuiPersistentRequestBuilder.swift`, `CloudTuiRemoteColors.swift`, `CloudTuiResolvedSurface.swift`.

## What stays in the app

- `CloudTuiManualMirrorSession` (and `+Capabilities`): it binds a `TerminalSurface`.
- `CloudTuiCommandRunning`, `CloudTuiDaemonAnswer`, `CloudTuiPersistentResourceConnection`: they speak `CloudMachineLink.LinkError`, which is nested in the app's `CloudMachineLink`. Moving `LinkError` out is the next step for them.

## What changed besides the move

- Declarations became `public`. Structs that relied on the synthesized initializer (`CloudTuiClientPaths.DeviceRecord`, `CloudTuiLegacySnapshotParser`, `CloudTuiManualIOFrameDecoder`, `CloudTuiManualIOResizeScheduler`) got an explicit `public init` with the same parameters.
- `CloudTuiManualIOResizeScheduler`'s `private(set)` state is publicly readable, as the app's tests read it.
