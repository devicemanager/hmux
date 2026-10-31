<h1 align="center">hmux</h1>
<p align="center">A Ghostty-based macOS terminal for AI coding agents, with an iPhone app that pairs over your own tailnet. No account, no cloud.</p>

<p align="center">
  <a href="https://ko-fi.com/devicemanager"><img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FF5E5B?logo=kofi&logoColor=white" alt="Buy me a coffee on Ko-fi" /></a>
</p>

hmux is a personal fork of [cmux](https://github.com/manaflow-ai/cmux) by
Manaflow, Inc. and its contributors. The terminal, sidebar, browser, CLI and
iPhone app are their work; all credit goes to them. hmux is not affiliated with
or endorsed by Manaflow. See [NOTICE](NOTICE.md).

## What hmux changes

cmux connects your Mac and iPhone through a cmux account, Iroh relays and push
notifications. hmux builds a **local-only** version instead, for homelabs and
on-prem setups where nothing should leave your own machines:

- **Pairing over your tailnet.** The iPhone pairs with the Mac using a one-time
  code and connects directly over [Tailscale](https://tailscale.com) or a
  self-hosted [Headscale](https://headscale.net) server.
- **No account or cloud.** No cmux account, Cloud VMs, Iroh relays, push,
  device discovery, auto-update or telemetry. Settings hides the sections that
  would need them.
- **Its own name and bundle IDs.** hmux installs next to the official cmux
  apps and never replaces them, so you can use both.

Everything else is cmux: vertical tabs, notification rings, split panes, the
in-app browser, the socket API and agent integrations. hmux follows upstream
through regular syncs.

## Download

**Mac:** download the DMG from the [latest release](https://github.com/devicemanager/hmux/releases/latest),
open it and drag hmux to Applications. It is signed and notarized by Apple and
needs macOS 14 or later. There is no auto-update: download new versions from
Releases.

**iPhone:** not in the App Store. Build it yourself as described below.

hmux is early and maintained by one person.

## Build

You need macOS 14 or later, Xcode, an Apple developer team (Developer ID and a
notarization profile for the Mac app, a development profile for the iPhone app),
and Tailscale or Headscale on both devices.

```bash
git clone --recurse-submodules https://github.com/devicemanager/hmux.git
cd hmux
cp .env-local.template .env-local   # fill in your team, bundle prefix and signing
scripts/build-local-only-mac.sh     # builds, notarizes and installs the Mac app
ios/scripts/build-local-only.sh     # builds and installs the iPhone app by cable
```

`ios/scripts/build-local-only.sh --ota-dir <dir> --ota-url <https-url>` writes
an over-the-air install page instead. The first build downloads a prebuilt
GhosttyKit when one matches the `ghostty` submodule, and otherwise builds it
with [Zig](https://ziglang.org).

## Documentation

- **Features and configuration:** the [cmux docs](https://cmux.com/docs/getting-started)
  apply to hmux too. Read `cmux` as `hmux` in commands and paths: the CLI is
  `hmux` and settings live in `~/.config/hmux/hmux.json`. The pages about
  accounts, Cloud, TestFlight and Founders Edition don't apply.
- **Working on the fork:** [docs/solo-fork.md](docs/solo-fork.md) covers
  building, syncing upstream and using official cmux alongside hmux.
- **The original README:** [cmux's README](https://github.com/manaflow-ai/cmux#readme)
  has the full feature tour and keyboard shortcuts.

## Feedback and support

Report hmux problems in this repository's
[issues](https://github.com/devicemanager/hmux/issues), not to cmux. If hmux is
useful to you, you can [buy me a coffee](https://ko-fi.com/devicemanager). To
support the people who built the app, see
[cmux Founders Edition](https://github.com/manaflow-ai/cmux#founders-edition).

## License

Same as cmux: the apps and CLI are GPL-3.0-or-later, and the server directories
listed in [LICENSE](LICENSE) are under the Business Source License 1.1.
