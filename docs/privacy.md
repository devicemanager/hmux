# hmux privacy policy

This policy covers the local-only hmux apps for Mac, iPhone and iPad, published
at https://github.com/devicemanager/hmux.

## What we collect

Nothing. hmux has no account, no servers of its own, no analytics, no
advertising and no crash reporting. The developer receives no data from the
apps.

## Where your data goes

The iPhone or iPad app connects only to Macs you pair it with, directly over
your own Tailscale or Headscale network. Terminal contents, keystrokes and
workspace names travel only between your devices. The apps contact no other
servers. Pairing details and saved sessions stay on your devices.

Tailscale or Headscale carries the connection. Their privacy terms apply to
that service, not this policy.

## Permissions

- **Camera:** scans the Mac's pairing QR code. Images are not stored or sent.
- **Local network:** connects to your Mac.
- **Microphone and speech recognition:** optional dictation into the message
  box. Speech is recognized on the device when it supports that. Otherwise
  iOS may use Apple's speech recognition service, under Apple's privacy
  policy.
- **Photos:** optional, to attach a photo you choose to a terminal on your Mac.

## Changes and contact

Changes to this policy appear in this file's history on GitHub. Questions go
to the [issues](https://github.com/devicemanager/hmux/issues) of the
repository.
