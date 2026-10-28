# HmuxMobileShellUI

The SwiftUI half of the hmux iOS shell.

This is the leaf UI layer extracted out of the `hmuxFeature` catch-all target. It
owns the workspace shell, sign-in, pairing, terminal detail, and root routing
views, plus the iOS push coordinator that the root view injects into the
SwiftUI environment.

It depends only downward: the decomposed domain facade
(`HmuxMobileShell.HMUXMobileShellStore`), the core/value packages
(`HMUXMobileCore`, `HmuxMobileShellModel`, `HmuxMobileWorkspace`,
`HmuxMobileSupport`), `HmuxAuthRuntime` for the injected `AuthCoordinator`,
`HmuxMobileTerminal` for the libghostty surface, and `HmuxMobileCamera` for the
QR-pairing capture stack. It never reaches into RPC/transport concretes.

`hmuxFeature` now sits *above* this package as the composition root
(`HMUXMobileRootScene`, `HMUXMobileRuntime`, the auth/push wiring) and
re-exports the package so the app shell keeps `import hmuxFeature` working.

## Entry points

- ``HMUXMobileAppView`` — the live mobile UI root, mounted by `HMUXMobileRootScene`.
- ``MobilePushCoordinator`` — APNs↔store bridge, constructed at the app root.
