hmux for iOS is a companion app: it shows and controls terminal sessions of a
Mac running hmux (free, https://github.com/devicemanager/hmux). The two connect
directly over the user's own Tailscale or Headscale network. There is no account,
sign-in, server or in-app purchase, so no demo account exists.

Demo video of the full flow: <DEMO VIDEO URL>

How it works:
1. On the Mac, hmux shows a one-time pairing QR code (Settings → Mobile →
   Mobile Pairing → Open Pairing… → Show Pairing Code).
2. On the iPhone, Add Computer → Scan QR Code. The camera is used only for
   this.
3. The app lists the Mac's workspaces. Opening one shows its live terminal,
   and typing sends keystrokes to the Mac.

Permissions:
- Camera: scanning the pairing QR code.
- Local network: connecting to the user's Mac over Tailscale.
- Microphone and speech recognition: optional dictation into the message box.
- Photos: optional, attaching a photo to send to a terminal.

The app collects no data and contacts no servers other than the user's own
Mac. Crash reporting is turned off in this build.

hmux is an independent open-source fork of cmux (GPL-3.0) by Manaflow, Inc.,
distributed on the App Store with Manaflow's permission.
