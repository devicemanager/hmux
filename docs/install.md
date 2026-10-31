# Installing hmux

hmux has two parts: the Mac app, and an optional iPhone app that shows your
Mac's terminals. They connect directly over your own
[Tailscale](https://tailscale.com) or [Headscale](https://headscale.net)
network, so both devices need Tailscale installed and signed in to the same
tailnet.

Use the Mac app and the iPhone app from the **same release**. An older iPhone
app can connect to a newer Mac app (or the other way round) and still show an
empty terminal.

- [Without an Apple developer account](#without-an-apple-developer-account)
- [With an Apple developer account](#with-an-apple-developer-account)
- [Pair the iPhone with the Mac](#pair-the-iphone-with-the-mac)
- [Troubleshooting](#troubleshooting)

## Without an Apple developer account

### Mac

1. Download `hmux-<version>.dmg` from the
   [latest release](https://github.com/devicemanager/hmux/releases/latest).
2. Open it and drag hmux to Applications.

The app is signed and notarized, so it opens without warnings. hmux installs
next to the official cmux app and never replaces it. It has no auto-update:
download new versions from Releases.

### iPhone

The iPhone app isn't in the App Store. The release has an unsigned
`hmux-ios-<version>-unsigned.ipa`, which a sideloading tool signs with your own
Apple ID. A free Apple ID works. You can use a separate one if you'd rather not
enter your main Apple ID in a third-party tool.

1. Download the `.ipa` from the
   [latest release](https://github.com/devicemanager/hmux/releases/latest).
2. Install [Sideloadly](https://sideloadly.io) (or
   [AltStore](https://altstore.io)) on your Mac, and connect the iPhone by
   cable.
3. Drag the `.ipa` into Sideloadly, enter your Apple ID and click **Start**.
4. On the iPhone:
   - Turn on **Settings → Privacy & Security → Developer Mode** and restart
     when asked.
   - Trust your Apple ID under **Settings → General → VPN & Device
     Management**.

Limits of a free Apple ID: the app stops opening after **7 days** and must be
installed again (AltStore can refresh it automatically), and you can have at
most three sideloaded apps at a time.

## With an Apple developer account

### Mac

The DMG from Releases is already notarized: you can use it as is.

To build and sign the Mac app yourself instead:

1. In your developer account, create a **Developer ID Application**
   certificate and install it in your keychain.
2. Store notarization credentials once, with an
   [app-specific password](https://support.apple.com/102654):

   ```bash
   xcrun notarytool store-credentials hmux-notary \
     --apple-id <you@example.com> --team-id <TEAMID> --password <app-specific-password>
   ```

3. Optional but recommended: create an App Store Connect API key (Users and
   Access → Integrations → App Store Connect API, role Developer). With it, the
   build script creates a provisioning profile that lets hmux keep its saved
   sessions encrypted in its own keychain group.
4. Clone the repository and fill in `.env-local`:

   ```bash
   git clone --recurse-submodules https://github.com/devicemanager/hmux.git
   cd hmux
   cp .env-local.template .env-local
   ```

   Set at least `HMUX_LOCAL_TEAM_ID`, `HMUX_LOCAL_BUNDLE_PREFIX` (a reverse-DNS
   prefix you own, such as `com.example`) and `HMUX_LOCAL_NOTARY_PROFILE=hmux-notary`.
   Comments in the file explain every setting.
5. Build, sign, notarize and install:

   ```bash
   scripts/build-local-only-mac.sh
   ```

   Quit hmux first if it's running. `--no-install` leaves the app in the build
   folder.

You need Xcode. The first build downloads a prebuilt GhosttyKit when one
matches, and otherwise builds it with [Zig](https://ziglang.org).

### iPhone

Either re-sign the release `.ipa` with your team, or build it yourself.

- **Re-sign:** follow the [steps above](#iphone) and enter the Apple ID of your
  developer account in Sideloadly. The app then stays valid for a year instead of
  7 days.
- **Build:** with `.env-local` filled in as for the Mac, connect the iPhone by
  cable and run:

  ```bash
  ios/scripts/build-local-only.sh
  ```

  It signs with a development profile for your bundle ID (Xcode creates one
  when you open any project of your team and register the iPhone). To install
  over the air instead, pass `--ota-dir <folder> --ota-url <https-url>` and open
  `<https-url>/install.html` on the iPhone. The folder must be served over
  HTTPS, and only iPhones registered in your developer account can install it.

  When you rebuild, raise `CURRENT_PROJECT_VERSION` in
  `ios/Config/Shared.xcconfig`, or iOS may keep the old app.

## Pair the iPhone with the Mac

1. Make sure Tailscale is connected on both devices.
2. On the Mac, open hmux **Settings → Mobile → Mobile Pairing → Open Pairing…**,
   then under **Pair without an account** click **Show Pairing Code**. The code
   works once and expires after five minutes.
3. On the iPhone, open hmux, go to **Add Computer**, tap **Scan QR Code** and
   point the camera at the code. Allow camera and local network access when
   asked.

The iPhone then lists the Mac's workspaces. It connects only to addresses in
Tailscale's ranges (`100.64.0.0/10` and `fd7a:115c:a1e0::/48`). With Headscale,
keep its `prefixes` setting at those defaults.

## Troubleshooting

- **The terminal on the iPhone stays empty, but typing reaches the Mac.** The
  Mac and iPhone apps come from different versions. Install both from the same
  release.
- **The iPhone can't reach the Mac.** Check that both show as connected in
  Tailscale, and that the iPhone allowed hmux to use the local network
  (Settings → Privacy & Security → Local Network).
- **The sideloaded app no longer opens.** A free Apple ID's signature expired
  after 7 days. Install the `.ipa` again, or let AltStore refresh it.

Report problems in this repository's
[issues](https://github.com/devicemanager/hmux/issues), not to cmux.
