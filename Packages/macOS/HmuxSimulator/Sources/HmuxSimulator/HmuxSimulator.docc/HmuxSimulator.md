# ``HmuxSimulator``

Use typed Simulator models, public `simctl` controls, and the supervised worker client that powers hmux Simulator panes.

## Target ownership

`HmuxSimulator` owns process-safe values, public command construction, and host-side worker supervision. `HmuxSimulatorWorker` owns private, version-gated Simulator framework access and can terminate without taking down hmux. `HmuxSimulatorUI` owns AppKit and SwiftUI presentation. The worker publishes versioned packed-BGRA slots through permission-restricted shared memory. The host maps them read-only, copies stable frames off-main, and presents immutable Core Graphics images. No CoreSimulator, SimulatorKit, or worker-owned IOSurface enters hmux presentation.

Private Simulator APIs must stay in the worker target. New control values belong in `Models`, public command operations in `Control`, wire messages in `WorkerProtocol`, and crash containment in `WorkerClient`.

Raw Web Inspector output crosses the process boundary as ordered ``SimulatorWebInspectorMessageChunk`` values. Consumers can stream chunks without assembling a heap snapshot or another large domain response into one host-worker frame.
